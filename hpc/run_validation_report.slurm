#!/bin/bash

#SBATCH --job-name=bsval_report
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=validation/results/logs/report_%j.out
#SBATCH --error=validation/results/logs/report_%j.err

set -euo pipefail
ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
VALIDATION_ROOT=${VALIDATION_ROOT:-$ROTBOSON_DIR/validation/results}
ell=${VALIDATION_ELL:-1}
potential=${VALIDATION_POTENTIAL:-free}
report_dir="$VALIDATION_ROOT/l${ell}/reports"
status=0
"${PYTHON_BIN:-python3}" "$ROTBOSON_DIR/scripts/validate_boson_stars.py" \
  --manifest "$ROTBOSON_DIR/validation/benchmarks.json" report \
  --root "$VALIDATION_ROOT" --ell "$ell" --potential "$potential" --output-dir "$report_dir" || status=$?
if [ "$potential" = "quartic" ]; then
  "${PYTHON_BIN:-python3}" "$ROTBOSON_DIR/scripts/validate_boson_stars.py" \
    --manifest "$ROTBOSON_DIR/validation/benchmarks.json" coupling-report \
    --scan-id "l${ell}_quartic_homotopy" --output-root "$ROTBOSON_DIR/out" \
    --output-dir "$report_dir" || status=$?
  "${PYTHON_BIN:-python3}" "$ROTBOSON_DIR/scripts/validate_boson_stars.py" \
    --manifest "$ROTBOSON_DIR/validation/benchmarks.json" sequence-peak-report \
    --target-id "l${ell}_quartic_L200_w0820_fundamental" \
    --output-root "$ROTBOSON_DIR/out" --output-dir "$report_dir" || status=$?
fi
exit "$status"
