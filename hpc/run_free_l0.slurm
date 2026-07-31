#!/bin/bash

#SBATCH --job-name=rotboson_free_l0
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_free_l0_%j.out
#SBATCH --error=rotboson_free_l0_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out
SCAN_DIR=$RUN_DIR/hpc_free_l0_sequence

cd "$RUN_DIR"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"

echo "Running production free-field l=0 seed plus continuation"
echo "START_TIME=$(date -Is)"
run_sequence "$ROTBOSON_DIR" "free" "none" "0.0" "$SCAN_DIR" "free_l0" "0"
echo "END_TIME=$(date -Is)"
