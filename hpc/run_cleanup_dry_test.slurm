#!/bin/bash

#SBATCH --job-name=rotboson_clean_dry
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00
#SBATCH --output=rotboson_clean_dry_%j.out
#SBATCH --error=rotboson_clean_dry_%j.err

set -euo pipefail

ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
RUN_DIR=$ROTBOSON_DIR/out

echo "Removing dry-test parameter files and solution data"
rm -rf "$RUN_DIR/hpc_dry_params"
find "$RUN_DIR" -maxdepth 1 -type d -name "pot=free,l=1,w=*,dr=2.50000E-01,N=0064*" -exec rm -rf {} +
find "$RUN_DIR" -maxdepth 1 -type d -name "pot=quartic,lambda_4=2.51327E+03,l=1,w=*,dr=2.50000E-01,N=0064*" -exec rm -rf {} +

echo "Removing dry-test SLURM logs from submit directory"
find "$ROTBOSON_DIR" -maxdepth 1 -type f \( -name "rotboson_dry_*.out" -o -name "rotboson_dry_*.err" \) -delete
