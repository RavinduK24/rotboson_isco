#!/bin/bash

#SBATCH --job-name=sphboson_free_l0
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --output=sphboson_free_l0_%j.out
#SBATCH --error=sphboson_free_l0_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

SPHBOSON_DIR=${SPHBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON/sphboson}
SCAN_DIR=$SPHBOSON_DIR/out/hpc_free_l0_$(date +%Y%m%d_%H%M%S)

source "$SPHBOSON_DIR/hpc/run_sequence_lib.sh"
run_sequence "$SPHBOSON_DIR" "free" "none" "0.0" "$SCAN_DIR" "free_l0"
