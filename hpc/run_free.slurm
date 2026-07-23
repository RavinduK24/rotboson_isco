#!/bin/bash

#SBATCH --job-name=rotboson_free
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=12:00:00
#SBATCH --output=rotboson_free_%j.out
#SBATCH --error=rotboson_free_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out

cd "$RUN_DIR"

echo "Running free potential"
echo "START_TIME=$(date -Is)"
"$ROTBOSON_DIR/ROTBOSON" "$ROTBOSON_DIR/examples/free.par"
echo "END_TIME=$(date -Is)"
