#!/bin/bash

#SBATCH --job-name=rotboson_l1isco
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=rotboson_l1isco_%j.out
#SBATCH --error=rotboson_l1isco_%j.err

# Extract circular-orbit and ISCO data only from retained, converged l=1
# profiles in the completed quartic-coupling families. This never reruns the
# equilibrium solver and never removes profiles or existing results.
set -euo pipefail

ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
OUTPUT_ROOT=$ROTBOSON_DIR/out
RESULT_TAG=${ISCO_RESULT_TAG:-isco_l1_quartic_families}
RESULT_DIR=$ROTBOSON_DIR/results/$RESULT_TAG
REQUIRED_FILES=(
  sph_rr.asc sph_th.asc sph_log_alpha_f.asc sph_beta_f.asc
  sph_log_h_f.asc sph_log_a_f.asc run_metadata.txt
)

# Some clusters expose an older ``python3`` by default.  The ISCO processor
# needs Python >= 3.7 (``from __future__ import annotations``) plus NumPy and
# SciPy.  Respect an explicit PYTHON_BIN, otherwise choose a working modern
# interpreter from the versions available on the PolyU cluster.
if [[ -n ${PYTHON_BIN:-} ]]; then
  PYTHON_CANDIDATES=("$PYTHON_BIN")
else
  # This is the same Anaconda interpreter used by the existing validation
  # submission helpers on the PolyU cluster.  Keep generic candidates after
  # it for portability to other systems.
  PYTHON_CANDIDATES=(
    /hpcapps/Anaconda3/Anaconda3-2023.03-1/bin/python3
    python3.12 python3.11 python3.10 python3.9 python3
  )
fi
PYTHON_BIN=''
for candidate in "${PYTHON_CANDIDATES[@]}"; do
  command -v "$candidate" >/dev/null 2>&1 || continue
  if "$candidate" -c 'from __future__ import annotations; import numpy, scipy' \
      >/dev/null 2>&1; then
    PYTHON_BIN=$(command -v "$candidate")
    break
  fi
done
if [[ -z "$PYTHON_BIN" ]]; then
  echo 'ERROR: no compatible Python with NumPy and SciPy was found.' >&2
  echo 'Set PYTHON_BIN to a Python >= 3.7 environment containing NumPy and SciPy.' >&2
  exit 1
fi
echo "Using Python: $PYTHON_BIN ($($PYTHON_BIN --version 2>&1))"

has_orbit_input() {
  local directory=$1 file
  [[ -d "$directory" ]] || return 1
  for file in "${REQUIRED_FILES[@]}"; do
    [[ -f "$directory/$file" ]] || return 1
  done
  grep -qx 'convergence_status=converged' "$directory/run_metadata.txt"
}

if [[ -d "$RESULT_DIR" ]] && [[ -n $(find "$RESULT_DIR" -mindepth 1 -print -quit) ]]; then
  echo "ERROR: result directory already contains files: $RESULT_DIR" >&2
  echo "Choose a new tag, for example ISCO_RESULT_TAG=isco_l1_quartic_families_rerun." >&2
  exit 2
fi

shopt -s nullglob
declare -a RUN_ROOTS=()
declare -A SEEN=()
declare -A COUNTS=()

add_candidate() {
  local label=$1 directory=$2 canonical
  has_orbit_input "$directory" || return 0
  canonical=$(readlink -f -- "$directory")
  [[ -z ${SEEN[$canonical]+x} ]] || return 0
  SEEN[$canonical]=1
  RUN_ROOTS+=("$canonical")
  COUNTS[$label]=$(( ${COUNTS[$label]:-0} + 1 ))
}

for lambda in 0 10 50 100; do
  family_root=$OUTPUT_ROOT/family_scan_Lambda_${lambda}/l1/work
  for candidate in "$family_root"/pot=*,l=1,w=*; do
    add_candidate "Lambda=${lambda}" "$candidate"
  done
done

# Lambda=200 was produced before the disk-limited family workflow, so its
# production-grid profiles live directly beneath out/.
for candidate in "$OUTPUT_ROOT"/pot=quartic,lambda_4=2.51327E+03,l=1,w=*,dr=1.25000E-01,N=0512*; do
  add_candidate "Lambda=200" "$candidate"
done

if (( ${#RUN_ROOTS[@]} == 0 )); then
  echo 'ERROR: no retained converged l=1 family profiles with spherical metric files were found.' >&2
  exit 1
fi

echo "Selected ${#RUN_ROOTS[@]} retained profiles for ISCO processing"
for lambda in 0 10 50 100 200; do
  label="Lambda=${lambda}"
  echo "  ${label}: ${COUNTS[$label]:-0} profile(s)"
done

cd "$ROTBOSON_DIR"
"$PYTHON_BIN" scripts/rotboson_isco.py "${RUN_ROOTS[@]}" \
  --output-dir "$RESULT_DIR" \
  --export-profiles

echo "ISCO scan complete: $RESULT_DIR"
