#!/bin/bash

#SBATCH --job-name=rotboson_qhom_low
#SBATCH --partition=h07q2
#SBATCH --array=1-4%2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_qhom_low_%A_%a.out
#SBATCH --error=rotboson_qhom_low_%A_%a.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out
SCAN_DIR=$RUN_DIR/hpc_quartic_homotopy
ELL=${SLURM_ARRAY_TASK_ID:?This file must be submitted with sbatch as an array job}
PAPER_LAMBDAS=(1 2 5 10 20 40 60 80 100)
CODE_LAMBDA4S=(12.566370614359172 25.132741228718345 62.83185307179586 125.66370614359172 251.32741228718345 502.6548245743669 753.9822368615503 1005.3096491487338 1256.6370614359173)

cd "$RUN_DIR"
source "$ROTBOSON_DIR/hpc/job_utils.sh"
cleanup_old_slurm_logs "rotboson_qhom_low" "$ROTBOSON_DIR"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"
initialize_homotopy "$ROTBOSON_DIR" "$SCAN_DIR" "$ELL"

CURRENT_DIR=$(weak_seed_dir "free" "none" "0.0" "$ELL")
validate_solution "$CURRENT_DIR"
for INDEX in "${!PAPER_LAMBDAS[@]}"; do
  run_homotopy_step "$ROTBOSON_DIR" "$SCAN_DIR" "$ELL" "$CURRENT_DIR" \
    "${PAPER_LAMBDAS[$INDEX]}" "${CODE_LAMBDA4S[$INDEX]}"
  CURRENT_DIR=$HOMOTOPY_RESULT
done
echo "Low homotopy complete for l=$ELL at $CURRENT_DIR"
