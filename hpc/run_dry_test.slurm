#!/bin/bash

#SBATCH --job-name=rotboson_dry
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=rotboson_dry_%j.out
#SBATCH --error=rotboson_dry_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
RUN_DIR=$ROTBOSON_DIR/out
DRY_PARAM_DIR=$RUN_DIR/hpc_dry_params
DRY_LAMBDA4=1.0

source "$ROTBOSON_DIR/hpc/job_utils.sh"
cleanup_old_slurm_logs "rotboson_dry" "$ROTBOSON_DIR"

cleanup_dry_outputs() {
  rm -rf "$DRY_PARAM_DIR"
  find "$RUN_DIR" -maxdepth 1 -type d -name "pot=free,l=1,w=*,dr=2.50000E-01,N=0064*" -exec rm -rf {} +
  find "$RUN_DIR" -maxdepth 1 -type d -name "pot=quartic,lambda_4=1.00000E+00,l=1,w=*,dr=2.50000E-01,N=0064*" -exec rm -rf {} +
}

mkdir -p "$DRY_PARAM_DIR"
cd "$RUN_DIR"

echo "Cleaning previous dry-test data"
cleanup_dry_outputs
mkdir -p "$DRY_PARAM_DIR"

cp "$ROTBOSON_DIR/examples/free.par" "$DRY_PARAM_DIR/free_dry.par"
cp "$ROTBOSON_DIR/examples/quartic.par" "$DRY_PARAM_DIR/quartic_dry.par"
sed -i -E "s/^[[:space:]]*lambda_4[[:space:]]*=.*/lambda_4 = ${DRY_LAMBDA4}/" "$DRY_PARAM_DIR/quartic_dry.par"
for PARAM_FILE in "$DRY_PARAM_DIR/free_dry.par" "$DRY_PARAM_DIR/quartic_dry.par"; do
  {
    printf "\n# HPC explicit parser defaults\n"
    printf "max_initial_guess_checks = 8\n"
    printf "norm_f0_target = 1.0E-5\n"
    printf "rr_phi_max_minimum = 1.0\n"
    printf "rr_phi_max_maximum = 100.0\n"
  } >> "$PARAM_FILE"
done

echo "START_DRY_FREE=$(date -Is)"
"$ROTBOSON_DIR/ROTBOSON" "$DRY_PARAM_DIR/free_dry.par"
echo "END_DRY_FREE=$(date -Is)"

echo "START_DRY_QUARTIC=$(date -Is)"
"$ROTBOSON_DIR/ROTBOSON" "$DRY_PARAM_DIR/quartic_dry.par"
echo "END_DRY_QUARTIC=$(date -Is)"

echo "Dry test passed; removing dry-test data and logs"
cleanup_dry_outputs
