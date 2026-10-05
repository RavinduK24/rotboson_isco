#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash hpc/submit_interacting_validation.sh [--ell 1] [--dry-run]

Validates the rotating quartic self-interaction workflow. The current
literature target is Grandclement et al. (2014), Lambda=200, l=1.

Environment overrides:
  ROTBOSON_DIR                checkout root
  INTERACTING_VALIDATION_ROOT isolated exact/grid validation root
  PYTHON_BIN                  Python executable (default: python3)
EOF
}

ell=1
dry_run=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --ell)
      [ "$#" -ge 2 ] || { echo "ERROR: --ell requires a value" >&2; exit 2; }
      ell="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[ "$ell" = "1" ] || {
  echo "ERROR: the registered interacting literature target currently supports only --ell 1" >&2
  exit 2
}

ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
INTERACTING_VALIDATION_ROOT=${INTERACTING_VALIDATION_ROOT:-$ROTBOSON_DIR/validation/results/interacting/quartic_Lambda_200}
PYTHON_BIN=${PYTHON_BIN:-python3}
manifest="$ROTBOSON_DIR/validation/benchmarks.json"
validator="$ROTBOSON_DIR/scripts/validate_boson_stars.py"
potential=quartic

[ -f "$manifest" ] || { echo "ERROR: missing $manifest" >&2; exit 2; }
mkdir -p "$INTERACTING_VALIDATION_ROOT/logs"

echo "Rotating self-interaction literature validation"
echo "  checkout: $ROTBOSON_DIR"
echo "  validation outputs: $INTERACTING_VALIDATION_ROOT"
echo "  homotopy/branch outputs: $ROTBOSON_DIR/out"
echo "  resources: partition=h07q2 cpus=4 memory=128G time=72h concurrency=2"
"$PYTHON_BIN" "$validator" --manifest "$manifest" manifest-summary \
  --ell "$ell" --potential "$potential"

target_count=$("$PYTHON_BIN" "$validator" --manifest "$manifest" targets \
  --ell "$ell" --potential "$potential" | wc -l | tr -d '[:space:]')
matrix_count=$("$PYTHON_BIN" "$validator" --manifest "$manifest" matrix \
  --ell "$ell" --potential "$potential" --exclude-production | wc -l | tr -d '[:space:]')
[ "$target_count" -gt 0 ] && [ "$matrix_count" -gt 0 ] || {
  echo "ERROR: no interacting targets or convergence cases are registered" >&2
  exit 2
}
target_array="0-$((target_count - 1))%2"
matrix_array="0-$((matrix_count - 1))%2"
if [ "$target_count" -eq 1 ]; then
  target_array=0
fi
if [ "$matrix_count" -eq 1 ]; then
  matrix_array=0
fi

submit() {
  local dependency="$1"
  shift
  local command=(sbatch --parsable)
  if [ -n "$dependency" ]; then
    command+=("--dependency=afterok:${dependency}")
  fi
  command+=(--export="ALL,ROTBOSON_DIR=$ROTBOSON_DIR,VALIDATION_ROOT=$INTERACTING_VALIDATION_ROOT,VALIDATION_ELL=$ell,VALIDATION_POTENTIAL=$potential,VALIDATION_SEED_ROOT=$ROTBOSON_DIR/out,PYTHON_BIN=$PYTHON_BIN")
  command+=("$@")
  if [ "$dry_run" = "1" ]; then
    printf 'DRY-RUN:'
    printf ' %q' "${command[@]}"
    printf '\n'
    DRY_COUNTER=$((DRY_COUNTER + 1))
    SUBMITTED_JOB="DRY${DRY_COUNTER}"
  else
    SUBMITTED_JOB=$("${command[@]}")
    SUBMITTED_JOB=${SUBMITTED_JOB%%;*}
    echo "Submitted job $SUBMITTED_JOB: ${command[*]}" >&2
  fi
}

DRY_COUNTER=0
SUBMITTED_JOB=""
cd "$ROTBOSON_DIR"

submit "" "$ROTBOSON_DIR/hpc/run_validation_build.slurm"
build_job=$SUBMITTED_JOB
submit "$build_job" --array=1 "$ROTBOSON_DIR/hpc/run_free.slurm"
free_job=$SUBMITTED_JOB
submit "$free_job" --array=1 "$ROTBOSON_DIR/hpc/run_quartic_homotopy_low.slurm"
low_job=$SUBMITTED_JOB
submit "$low_job" --array=1 "$ROTBOSON_DIR/hpc/run_quartic_homotopy_high.slurm"
high_job=$SUBMITTED_JOB
submit "$high_job" --array=1 "$ROTBOSON_DIR/hpc/run_quartic.slurm"
branch_job=$SUBMITTED_JOB
submit "$branch_job" --array="$target_array" "$ROTBOSON_DIR/hpc/run_validation_exact.slurm"
exact_job=$SUBMITTED_JOB
submit "$exact_job" --array="$matrix_array" "$ROTBOSON_DIR/hpc/run_validation_convergence.slurm"
convergence_job=$SUBMITTED_JOB
submit "$convergence_job" "$ROTBOSON_DIR/hpc/run_validation_report.slurm"
report_job=$SUBMITTED_JOB

echo "Dependency chain:"
echo "  build=$build_job -> free-seed=$free_job -> homotopy-low=$low_job"
echo "  -> homotopy-high=$high_job -> Lambda200-branch=$branch_job"
echo "  -> exact=$exact_job -> convergence=$convergence_job -> report=$report_job"
echo "Reports: $INTERACTING_VALIDATION_ROOT/l${ell}/reports/"
