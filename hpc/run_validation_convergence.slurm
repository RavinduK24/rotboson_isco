#!/bin/bash

#SBATCH --job-name=bsval_grid
#SBATCH --partition=h07q2
#SBATCH --array=0-15%2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=validation/results/logs/convergence_%A_%a.out
#SBATCH --error=validation/results/logs/convergence_%A_%a.err

set -euo pipefail
export MKLROOT=${MKLROOT:-$HOME/intel/mkl/2024.1}
export LIBCONFIGROOT=${LIBCONFIGROOT:-$HOME/local}
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}
ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
VALIDATION_ROOT=${VALIDATION_ROOT:-$ROTBOSON_DIR/validation/results}
export ROTBOSON_DIR VALIDATION_ROOT
source "$ROTBOSON_DIR/hpc/validation_lib.sh"
ell=${VALIDATION_ELL:-1}
potential=${VALIDATION_POTENTIAL:-free}
mapfile -t matrix < <(validation_python matrix --ell "$ell" --potential "$potential" --exclude-production)
row=${matrix[${SLURM_ARRAY_TASK_ID:?submit as an array job}]:-}
[ -n "$row" ] || { echo "ERROR: no convergence case at array index $SLURM_ARRAY_TASK_ID" >&2; exit 2; }
IFS=$'\t' read -r target_id grid_id n r_max omega branch target_potential coupling_name coupling_value <<< "$row"
echo "Convergence target=$target_id grid=$grid_id N=$n Rmax=$r_max"
run_convergence_target "$ell" "$target_id" "$grid_id" "$n" "$r_max" "$omega" \
  "$target_potential" "$coupling_name" "$coupling_value"
