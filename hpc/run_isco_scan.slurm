#!/bin/bash

#SBATCH --job-name=rotboson_isco
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=rotboson_isco_%j.out
#SBATCH --error=rotboson_isco_%j.err

set -euo pipefail

# ---------------------------------------------------------------------------
# Main controls. Change RUN_ROOTS and RESULT_TAG for each postprocessing pass.
# Add --boson-mass-ev below only when you want physical Hz/km columns.
# ---------------------------------------------------------------------------
ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_ROOTS=("out")
RESULT_TAG=isco_scan
EXTRA_ARGS=("--export-profiles" "--plots" "--strict")

cd "$ROTBOSON_DIR"

python3 scripts/rotboson_isco.py "${RUN_ROOTS[@]}" \
  --output-dir "results/${RESULT_TAG}" \
  "${EXTRA_ARGS[@]}"
