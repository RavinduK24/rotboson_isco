#!/bin/bash

#SBATCH --job-name=rotboson_qhom_high
#SBATCH --partition=h07q2
#SBATCH --array=1-4%2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_qhom_high_%A_%a.out
#SBATCH --error=rotboson_qhom_high_%A_%a.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out
SCAN_DIR=$RUN_DIR/hpc_quartic_homotopy
ELL=${SLURM_ARRAY_TASK_ID:?This file must be submitted with sbatch as an array job}
PAPER_LAMBDAS=(120 140 160 180 200)
CODE_LAMBDA4S=(1507.9644737231006 1759.291886010284 2010.6192982974676 2261.946710584651 2513.2741228718345)

cd "$RUN_DIR"
source "$ROTBOSON_DIR/hpc/job_utils.sh"
cleanup_old_slurm_logs "rotboson_qhom_high" "$ROTBOSON_DIR"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"

CURRENT_DIR=$(homotopy_checkpoint "$SCAN_DIR" "$ELL" 100)
for INDEX in "${!PAPER_LAMBDAS[@]}"; do
  run_homotopy_step "$ROTBOSON_DIR" "$SCAN_DIR" "$ELL" "$CURRENT_DIR" \
    "${PAPER_LAMBDAS[$INDEX]}" "${CODE_LAMBDA4S[$INDEX]}"
  CURRENT_DIR=$HOMOTOPY_RESULT
done
echo "High homotopy complete for l=$ELL at $CURRENT_DIR"
