#!/bin/bash

#SBATCH --job-name=rotboson_quartic
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_quartic_%j.out
#SBATCH --error=rotboson_quartic_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out
SCAN_DIR=$RUN_DIR/hpc_quartic_lambda_4_scan
COUPLING_VALUES=("0.0" "1.0e-3" "1.0e-2" "1.0e-1" "1.0" "10.0")

mkdir -p "$SCAN_DIR/params"
cd "$RUN_DIR"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"

for LAMBDA in "${COUPLING_VALUES[@]}"; do
  LABEL="quartic_lambda_4_$(label_for_value "$LAMBDA")"

  echo "============================================================"
  echo "Running production quartic sequence lambda_4=$LAMBDA"
  echo "START_TIME=$(date -Is)"
  run_sequence "$ROTBOSON_DIR" "quartic" "lambda_4" "$LAMBDA" "$SCAN_DIR" "$LABEL"
  echo "END_TIME=$(date -Is)"
done
