#!/bin/bash

#SBATCH --job-name=rotboson_dry_free
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --output=rotboson_dry_free_%j.out
#SBATCH --error=rotboson_dry_free_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
RUN_DIR=$ROTBOSON_DIR/out
DRY_PARAM_DIR=$RUN_DIR/hpc_dry_params

mkdir -p "$DRY_PARAM_DIR"
cd "$RUN_DIR"

echo "Cleaning previous dry free-field data"
find "$RUN_DIR" -maxdepth 1 -type d -name "pot=free,l=1,w=*,dr=2.50000E-01,N=0064*" -exec rm -rf {} +

cp "$ROTBOSON_DIR/examples/free.par" "$DRY_PARAM_DIR/free_dry.par"

echo "START_DRY_FREE=$(date -Is)"
"$ROTBOSON_DIR/ROTBOSON" "$DRY_PARAM_DIR/free_dry.par"
echo "END_DRY_FREE=$(date -Is)"
