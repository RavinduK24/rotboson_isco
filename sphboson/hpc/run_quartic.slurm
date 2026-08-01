#!/bin/bash

#SBATCH --job-name=sphboson_quartic_l0
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=72:00:00
#SBATCH --output=sphboson_quartic_l0_%j.out
#SBATCH --error=sphboson_quartic_l0_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

SPHBOSON_DIR=${SPHBOSON_DIR:-$HOME/SPHBOSON_ISCO/SPHBOSON}
SCAN_DIR=$SPHBOSON_DIR/out/hpc_quartic_l0_$(date +%Y%m%d_%H%M%S)
COUPLING_VALUES=("0.0" "1.0e-3" "1.0e-2" "1.0e-1" "1.0" "10.0")

source "$SPHBOSON_DIR/hpc/run_sequence_lib.sh"
for LAMBDA in "${COUPLING_VALUES[@]}"; do
  LABEL="quartic_lambda_4_$(label_for_value "$LAMBDA")"
  run_sequence "$SPHBOSON_DIR" "quartic" "lambda_4" "$LAMBDA" "$SCAN_DIR" "$LABEL"
done
