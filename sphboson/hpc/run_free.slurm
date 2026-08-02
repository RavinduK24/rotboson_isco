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
PHI0_VALUES=(${PHI0_VALUES:-0.005 0.0075 0.010 0.015 0.020 0.030 0.040 0.060 0.080 0.100 0.150 0.200 0.300 0.400})

source "$SPHBOSON_DIR/hpc/run_sequence_lib.sh"
run_phi0_scan "$SPHBOSON_DIR" "free" "none" "0.0" "$SCAN_DIR" "free_l0" "${PHI0_VALUES[@]}"
