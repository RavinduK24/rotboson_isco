#!/bin/bash

#SBATCH --job-name=rotboson_free
#SBATCH --partition=h07q2
#SBATCH --array=1-4%2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_free_%A_%a.out
#SBATCH --error=rotboson_free_%A_%a.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out
ELL=${SLURM_ARRAY_TASK_ID:?This file must be submitted with sbatch as an array job}
SCAN_DIR=$RUN_DIR/hpc_free_sequence/l${ELL}

cd "$RUN_DIR"
source "$ROTBOSON_DIR/hpc/job_utils.sh"
cleanup_old_slurm_logs "rotboson_free" "$ROTBOSON_DIR"
mkdir -p "$SCAN_DIR/params"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"

echo "Running free-field array task k=l=$ELL"
echo "START_TIME=$(date -Is)"
run_free_sequence "$ROTBOSON_DIR" "$SCAN_DIR" "$ELL"
echo "END_TIME=$(date -Is)"
