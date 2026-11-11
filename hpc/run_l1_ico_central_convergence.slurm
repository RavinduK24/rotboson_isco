#!/bin/bash
# Re-solve one fixed-frequency, l=1 peak model once at a coarser grid and
# compare it to the existing N=512 peak profile.  This is a low-cost central
# resolution diagnostic, not a three-grid convergence proof.
# Submit one coupling at a time: ICO_LAMBDA=0,10,50,100,200.
#
# Examples:
#   sbatch --export=ALL,ICO_LAMBDA=0 hpc/run_l1_ico_central_convergence.slurm
#   sbatch --export=ALL,ICO_LAMBDA=200 hpc/run_l1_ico_central_convergence.slurm
#SBATCH --job-name=rotboson_icocvg
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_icocvg_%j.out
#SBATCH --error=rotboson_icocvg_%j.err

set -euo pipefail
export MKLROOT=${MKLROOT:-$HOME/intel/mkl/2024.1}
export LIBCONFIGROOT=${LIBCONFIGROOT:-$HOME/local}
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}

ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
ICO_LAMBDA=${ICO_LAMBDA:?Set ICO_LAMBDA to 0, 10, 50, 100, or 200}
case "$ICO_LAMBDA" in 0|10|50|100|200) ;; *) echo 'Unsupported ICO_LAMBDA' >&2; exit 2;; esac
ICO_N=${ICO_N:-256}
[[ "$ICO_N" =~ ^[1-9][0-9]*$ ]] && (( ICO_N >= 64 )) || {
  echo 'ICO_N must be an integer of at least 64' >&2
  exit 2
}

# Same interpreter that works for the existing validation workflow.
PYTHON_BIN=${PYTHON_BIN:-/hpcapps/Anaconda3/Anaconda3-2023.03-1/bin/python3}
"$PYTHON_BIN" -c 'from __future__ import annotations; import numpy, scipy' >/dev/null

ROOT=$ROTBOSON_DIR/validation/results/ico_central_convergence/l1/Lambda_${ICO_LAMBDA}
STATE=$ROOT/state
PARAMS=$ROOT/params
WORK=$ROOT/work
REPORTS=$ROOT/reports
OUT=$ROTBOSON_DIR/out
mkdir -p "$STATE" "$PARAMS" "$WORK" "$REPORTS"

source "$ROTBOSON_DIR/hpc/validation_lib.sh"

peak_source() {
  local pointer=$OUT/family_scan_Lambda_${ICO_LAMBDA}/l1/state/best.path
  if [[ "$ICO_LAMBDA" != 200 ]]; then
    [[ -s "$pointer" ]] || { echo "ERROR: missing family peak pointer: $pointer" >&2; return 1; }
    readlink -f -- "$(head -n 1 "$pointer")"
    return
  fi
  "$PYTHON_BIN" - "$OUT/family_scan_Lambda_200/l1/sequence.csv" <<'PY'
import csv, sys
with open(sys.argv[1], newline='') as handle:
    rows = list(csv.DictReader(handle))
peak = max(rows, key=lambda row: float(row['M_Komar']))
print(peak['profile_path'])
PY
}

source=$(peak_source)
source=$(readlink -f -- "$source")
[[ -d "$source" ]] || { echo "ERROR: peak profile is missing: $source" >&2; exit 1; }
omega=$(metadata_value "$source" omega)
if [[ "$ICO_LAMBDA" == 0 ]]; then
  potential=free; coupling_name=none; coupling_value=0.0
else
  potential=quartic; coupling_name=lambda_4
  coupling_value=$("$PYTHON_BIN" - "$ICO_LAMBDA" <<'PY'
import math, sys
print('{:.17g}'.format(4.0 * math.pi * float(sys.argv[1])))
PY
)
fi

run_grid() {
  local grid_id=$1 n=$2 rmax=$3 seed=$4 pointer=$STATE/${grid_id}.path
  local parameter=$PARAMS/${grid_id}.par attempt=$WORK/${grid_id}
  if [[ -s "$pointer" && -d $(head -n 1 "$pointer") ]]; then
    GRID_SOLUTION=$(head -n 1 "$pointer")
    echo "Reusing $grid_id: $GRID_SOLUTION"
    return
  fi
  write_seeded_params "$parameter" "$seed" 1 "$n" "$rmax" omega "$omega" \
    "$potential" "$coupling_name" "$coupling_value"
  run_validation_attempt "$parameter" "$attempt"
  printf '%s\n' "$VALIDATION_SOLUTION" > "$pointer"
  GRID_SOLUTION=$VALIDATION_SOLUTION
  echo "Accepted $grid_id: $GRID_SOLUTION"
}

# Fixed Rmax isolates central resolution.  The pre-existing source is the
# retained N=512 peak profile; this fresh, configurable coarse solve holds omega fixed and
# exposes an ICO that merely tracks the grid scale.
run_grid R64_N${ICO_N} "$ICO_N" 64 "$source"
grid_test=$GRID_SOLUTION

RESULT_DIR=$REPORTS/isco
if [[ -d "$RESULT_DIR" ]] && [[ -n $(find "$RESULT_DIR" -mindepth 1 -print -quit) ]]; then
  echo "ERROR: existing ICO report directory: $RESULT_DIR" >&2
  echo "Choose a new convergence root or remove that completed report deliberately." >&2
  exit 2
fi
"$PYTHON_BIN" "$ROTBOSON_DIR/scripts/rotboson_isco.py" \
  "$source" "$grid_test" \
  --output-dir "$RESULT_DIR" --export-profiles
"$PYTHON_BIN" "$ROTBOSON_DIR/hpc/summarize_ico_convergence.py" \
  --summary "$RESULT_DIR/isco_summary.csv" \
  --output "$REPORTS/co_rotating_ico_convergence.csv"

echo "ICO central resolution diagnostic completed for Lambda=$ICO_LAMBDA, N=$ICO_N"
echo "Report: $REPORTS/co_rotating_ico_convergence.md"
