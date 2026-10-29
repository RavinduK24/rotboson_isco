#!/bin/bash
#SBATCH --job-name=rotboson_family
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_family_%j.out
#SBATCH --error=rotboson_family_%j.err

set -euo pipefail
export MKLROOT=${MKLROOT:-$HOME/intel/mkl/2024.1}
export LIBCONFIGROOT=${LIBCONFIGROOT:-$HOME/local}
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}

ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
LAMBDA=${FAMILY_LAMBDA:?Set FAMILY_LAMBDA to 0, 10, 50, or 100}
case "$LAMBDA" in 0|10|50|100) ;; *) echo 'Unsupported FAMILY_LAMBDA' >&2; exit 2;; esac
ELL=1
OUT=$ROTBOSON_DIR/out
SCAN=$OUT/family_scan_Lambda_${LAMBDA}/l1
WORK=$SCAN/work
STATE=$SCAN/state
SUMMARY=$SCAN/sequence.csv
MAX_STEPS=${FAMILY_MAX_STEPS:-100}
KEEP_EVERY=${FAMILY_KEEP_EVERY:-10}
SOFT_LIMIT_GIB=${FAMILY_SOFT_LIMIT_GIB:-55}
STEP_SCALE=${FAMILY_STEP_SCALE:-1.025}
[[ "$MAX_STEPS" =~ ^[1-9][0-9]*$ && "$KEEP_EVERY" =~ ^[1-9][0-9]*$ && \
   "$SOFT_LIMIT_GIB" =~ ^[1-9][0-9]*$ ]] || {
  echo 'FAMILY_MAX_STEPS, FAMILY_KEEP_EVERY and FAMILY_SOFT_LIMIT_GIB must be positive integers' >&2
  exit 2
}

cd "$OUT"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"
mkdir -p "$WORK" "$STATE" "$SCAN/params"
if [[ -f "$STATE/complete" ]]; then
  echo "Lambda=$LAMBDA family already completed; summary: $SUMMARY"
  exit 0
fi

seed_path() {
  local p source
  if [[ "$LAMBDA" == 0 ]]; then
    source=$(weak_seed_dir free none 0.0 1)
  elif [[ "$LAMBDA" == 50 ]]; then
    p=
    for candidate in 40 60 20 80; do
      if [[ -f "$OUT/hpc_quartic_homotopy/checkpoints/l1/Lambda_${candidate}.path" ]]; then
        p="$OUT/hpc_quartic_homotopy/checkpoints/l1/Lambda_${candidate}.path"
        break
      fi
    done
    [[ -n "$p" ]] || { echo 'A nearby Lambda=20,40,60,80 checkpoint is required for Lambda=50' >&2; return 1; }
    source=$(head -n 1 "$p")
  else
    p="$OUT/hpc_quartic_homotopy/checkpoints/l1/Lambda_${LAMBDA}.path"
    [[ -f "$p" ]] || { echo "Missing $p" >&2; return 1; }
    source=$(head -n 1 "$p")
  fi
  [[ "$source" == /* ]] || source="$OUT/$source"
  readlink -f -- "$source"
}

potential=quartic
coupling_name=lambda_4
if [[ "$LAMBDA" == 0 ]]; then potential=free; coupling_name=none; fi
coupling_value=$(/usr/bin/python3 - "$LAMBDA" <<'PY'
import math, sys
print('%.17g' % (4.0 * math.pi * float(sys.argv[1])))
PY
)
pattern=$(solution_family_pattern "$potential" "$coupling_name" "$coupling_value" 1)

latest_new_solution() {
  local marker=$1 item count=0
  NEW_SOLUTION=
  while IFS= read -r item; do
    NEW_SOLUTION=$item
    count=$((count + 1))
  done < <(find "$WORK" -maxdepth 1 -type d -name "$pattern" -newer "$marker" -print)
  [[ $count -eq 1 ]] || { echo "Expected one new solution; found $count" >&2; return 1; }
  validate_solution "$NEW_SOLUTION"
}

run_one() {
  local source=$1 scale=$2 step=$3 par="$SCAN/params/step_${step}.par" marker="$STATE/before_step"
  local n=512 dr=0.125 rmax=64
  if [[ -f "$STATE/inflight.step" ]] && [[ $(cat "$STATE/inflight.step") == "$step" ]]; then
    latest_new_solution "$marker"
    validate_continuation_step "$source" "$NEW_SOLUTION"
    if [[ "$step" != seed ]]; then validate_equilibrium_quality "$NEW_SOLUTION" 64; fi
    printf '%s\n' "$NEW_SOLUTION" > "$STATE/produced.path"
    return 0
  fi
  if [[ "$LAMBDA" == 50 && "$step" == seed ]]; then n=256; dr=0.0625; rmax=16; fi
  write_initial_data_params "$ROTBOSON_DIR" "$source" "$potential" "$coupling_name" \
    "$coupling_value" "$par" 1 "$scale" 0 1.0 "$n" "$dr" "$rmax" 300
  touch "$marker"
  printf '%s\n' "$step" > "$STATE/inflight.step"
  (cd "$WORK" && "$ROTBOSON_DIR/ROTBOSON" "$par")
  latest_new_solution "$marker"
  validate_continuation_step "$source" "$NEW_SOLUTION"
  if [[ "$step" != seed ]]; then
    validate_equilibrium_quality "$NEW_SOLUTION" 64
  fi
  printf '%s\n' "$NEW_SOLUTION" > "$STATE/produced.path"
}

record_solution() {
  local d=$1 step=$2 omega mass j phi r99 grv2 grv3
  omega=$(metadata_value "$d" omega)
  mass=$(metadata_value "$d" M_Komar)
  j=$(metadata_value "$d" J_Komar)
  phi=$(first_numeric_value "$d/phi_max.asc")
  r99=$(first_numeric_value "$d/r99.asc")
  grv2=$(metadata_value "$d" GRV2)
  grv3=$(metadata_value "$d" GRV3)
  printf '%s,%s,%s,%s,%s,%s,%s,%s,"%s"\n' \
    "$step" "$omega" "$mass" "$j" "$phi" "$r99" "$grv2" "$grv3" "$d" >> "$SUMMARY"
}

storage_guard() {
  local kib limit
  kib=$(du -sk "$ROTBOSON_DIR" | cut -f1)
  limit=$((SOFT_LIMIT_GIB * 1024 * 1024))
  if (( kib >= limit )); then
    echo "Stopping before quota: checkout uses ${kib} KiB (soft limit ${SOFT_LIMIT_GIB} GiB)" >&2
    return 1
  fi
}

source=$(seed_path)
validate_solution "$source"
if [[ ${FAMILY_DRY_RUN:-0} == 1 ]]; then
  printf 'Lambda=%s ell=1 source=%s\n' "$LAMBDA" "$source"
  printf 'Grid: N=512 Rmax=64; scale per step=%s; maximum steps=%s\n' "$STEP_SCALE" "$MAX_STEPS"
  printf 'Keep every %s-th full profile plus current and peak; soft limit=%s GiB\n' "$KEEP_EVERY" "$SOFT_LIMIT_GIB"
  printf 'Summary: %s\n' "$SUMMARY"
  exit 0
fi
if [[ ! -f "$STATE/current.path" ]]; then
  storage_guard
  if [[ "$LAMBDA" == 50 ]]; then
    if [[ -f "$STATE/seed.path" ]] && validate_solution "$(cat "$STATE/seed.path")" >/dev/null 2>&1; then
      source=$(cat "$STATE/seed.path")
    else
      run_one "$source" 1.0 seed
      source=$(cat "$STATE/produced.path")
      printf '%s\n' "$source" > "$STATE/seed.path"
      rm -f "$STATE/inflight.step" "$STATE/produced.path"
    fi
  fi
  run_one "$source" 1.0 initial
  current=$(cat "$STATE/produced.path")
  printf 'step,omega,M_Komar,J_Komar,phi_max,r99,GRV2,GRV3,profile_path\n' > "$SUMMARY"
  record_solution "$current" 0
  printf '%s\n' "$current" > "$STATE/current.path"
  printf '0\n' > "$STATE/step"
  printf '0\n' > "$STATE/declines"
  printf '%s\n' "$current" > "$STATE/best.path"
  metadata_value "$current" M_Komar > "$STATE/best.mass"
  rm -f "$STATE/inflight.step" "$STATE/produced.path"
fi

step=$(cat "$STATE/step")
declines=$(cat "$STATE/declines")
while (( step < MAX_STEPS )); do
  storage_guard
  previous=$(cat "$STATE/current.path")
  step=$((step + 1))
  run_one "$previous" "$STEP_SCALE" "$step"
  current=$(cat "$STATE/produced.path")
  mass=$(metadata_value "$current" M_Komar)
  best_mass=$(cat "$STATE/best.mass")
  record_solution "$current" "$step"
  if numeric_helper ge "$mass" "$best_mass"; then
    printf '%s\n' "$mass" > "$STATE/best.mass"
    printf '%s\n' "$current" > "$STATE/best.path"
    printf '%s\n' "$previous" > "$STATE/peak_before.path"
    rm -f "$STATE/peak_after.path"
    declines=0
  else
    if (( declines == 0 )); then
      printf '%s\n' "$current" > "$STATE/peak_after.path"
    fi
    declines=$((declines + 1))
  fi
  printf '%s\n' "$current" > "$STATE/current.path.tmp"
  mv "$STATE/current.path.tmp" "$STATE/current.path"
  printf '%s\n' "$step" > "$STATE/step"
  printf '%s\n' "$declines" > "$STATE/declines"
  rm -f "$STATE/inflight.step" "$STATE/produced.path"

  # Delete only this scan's old work products. Never touch the homotopy,
  # validated Lambda=200, or ordinary out/ solution directories.
  if (( step > 2 )); then
    while IFS= read -r old; do
      old_step=$(basename "$old" | sed -n 's/^step_\([0-9]*\)\.path$/\1/p')
      [[ -n "$old_step" ]] || continue
      old_dir=$(head -n 1 "$old")
      if [[ "$old_dir" == "$WORK"/* && "$old_dir" != "$current" && \
            "$old_dir" != "$previous" && "$old_dir" != "$(cat "$STATE/best.path")" && \
            "$old_dir" != "$(cat "$STATE/peak_before.path" 2>/dev/null)" && \
            "$old_dir" != "$(cat "$STATE/peak_after.path" 2>/dev/null)" ]] && \
         (( old_step % KEEP_EVERY != 0 )); then
        rm -rf -- "$old_dir"
        rm -f -- "$old"
      fi
    done < <(find "$STATE" -maxdepth 1 -name 'step_*.path' -type f -print)
  fi
  printf '%s\n' "$current" > "$STATE/step_${step}.path"
  echo "Lambda=$LAMBDA step=$step M=$mass retained_profile=$current"
  if (( declines >= 3 )); then
    printf 'peak_bracketed=%s\n' "$(date -Is)" > "$STATE/complete"
    echo "Peak crossed; summary: $SUMMARY"
    exit 0
  fi
done
echo "Reached FAMILY_MAX_STEPS=$MAX_STEPS before confirming mass peak; resubmit to continue" >&2
exit 1
