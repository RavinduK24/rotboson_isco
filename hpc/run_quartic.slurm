#!/bin/bash

#SBATCH --job-name=rotboson_q200
#SBATCH --partition=h07q2
#SBATCH --array=1-4%2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_q200_%A_%a.out
#SBATCH --error=rotboson_q200_%A_%a.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out
HOMOTOPY_DIR=$RUN_DIR/hpc_quartic_homotopy
ELL=${SLURM_ARRAY_TASK_ID:?This file must be submitted with sbatch as an array job}
SCAN_DIR=$RUN_DIR/hpc_quartic_Lambda_200/l${ELL}

cd "$RUN_DIR"
source "$ROTBOSON_DIR/hpc/job_utils.sh"
cleanup_old_slurm_logs "rotboson_q200" "$ROTBOSON_DIR"
mkdir -p "$SCAN_DIR/params"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"

SOURCE_DIR=$(homotopy_checkpoint "$HOMOTOPY_DIR" "$ELL" 200)
echo "Running Grandclement Lambda=200 branch k=l=$ELL from $SOURCE_DIR"
echo "START_TIME=$(date -Is)"
run_target_quartic_branch "$ROTBOSON_DIR" "$SCAN_DIR" "$ELL" "$SOURCE_DIR"
echo "END_TIME=$(date -Is)"
