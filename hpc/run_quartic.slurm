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
ELL_VALUES=(1 2 3 4)
CLEAN_OLD_DATA=${CLEAN_OLD_DATA:-1}

cd "$RUN_DIR"
source "$ROTBOSON_DIR/hpc/job_utils.sh"
cleanup_old_slurm_logs "rotboson_quartic" "$ROTBOSON_DIR"

if [ "$CLEAN_OLD_DATA" = "1" ]; then
  rm -rf "$SCAN_DIR"
fi
mkdir -p "$SCAN_DIR/params"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"

for LAMBDA in "${COUPLING_VALUES[@]}"; do
  for ELL in "${ELL_VALUES[@]}"; do
    LABEL="quartic_lambda_4_$(label_for_value "$LAMBDA")_l${ELL}"

    echo "============================================================"
    echo "Running production quartic sequence k=l=$ELL, lambda_4=$LAMBDA"
    echo "START_TIME=$(date -Is)"
    run_sequence "$ROTBOSON_DIR" "quartic" "lambda_4" "$LAMBDA" "$SCAN_DIR" "$LABEL" "$ELL"
    echo "END_TIME=$(date -Is)"
  done
done
