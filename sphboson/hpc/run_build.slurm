#!/bin/bash

#SBATCH --job-name=sphboson_build
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --output=sphboson_build_%j.out
#SBATCH --error=sphboson_build_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

SPHBOSON_DIR=${SPHBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON/sphboson}

cd "$SPHBOSON_DIR"
make clean
make all compiler=gnu
make test
