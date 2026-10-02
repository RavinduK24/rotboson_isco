#!/bin/bash

#SBATCH --job-name=bsval_third
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=validation/results/logs/third_branch_%j.out
#SBATCH --error=validation/results/logs/third_branch_%j.err

set -euo pipefail
export MKLROOT=${MKLROOT:-$HOME/intel/mkl/2024.1}
export LIBCONFIGROOT=${LIBCONFIGROOT:-$HOME/local}
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}
ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
VALIDATION_ROOT=${VALIDATION_ROOT:-$ROTBOSON_DIR/validation/results}
export ROTBOSON_DIR VALIDATION_ROOT
source "$ROTBOSON_DIR/hpc/validation_lib.sh"
run_branch_phase third "${VALIDATION_ELL:-1}"
