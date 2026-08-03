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
SCAN_DIR=$RUN_DIR/hpc_quartic_grandclement_lambda_200_scan
# Grandclement et al. PRD 90, 024068 use V=m^2 |Phi|^2 (1 + 2*pi*Lambda*|Phi|^2).
# ROTBOSON uses V=m^2 x + lambda_4*x^2/2 with m=1, so lambda_4 = 4*pi*Lambda.
COUPLING_VALUES=("2513.2741228718345")
ELL_VALUES=(1 2 3 4)
CLEAN_OLD_DATA=${CLEAN_OLD_DATA:-1}

cd "$RUN_DIR"
if [ "$CLEAN_OLD_DATA" = "1" ]; then
  rm -rf "$SCAN_DIR"
fi
mkdir -p "$SCAN_DIR/params"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"

for LAMBDA in "${COUPLING_VALUES[@]}"; do
  for ELL in "${ELL_VALUES[@]}"; do
    LABEL="quartic_Lambda200_l${ELL}"

    echo "============================================================"
    echo "Running production quartic sequence k=l=$ELL, paper Lambda=200, code lambda_4=$LAMBDA"
    echo "START_TIME=$(date -Is)"
    run_sequence "$ROTBOSON_DIR" "quartic" "lambda_4" "$LAMBDA" "$SCAN_DIR" "$LABEL" "$ELL"
    echo "END_TIME=$(date -Is)"
  done
done
