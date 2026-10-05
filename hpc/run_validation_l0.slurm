#!/bin/bash

#SBATCH --job-name=bsval_l0
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=validation/results/logs/l0_%j.out
#SBATCH --error=validation/results/logs/l0_%j.err

set -euo pipefail
export MKLROOT=${MKLROOT:-$HOME/intel/mkl/2024.1}
export LIBCONFIGROOT=${LIBCONFIGROOT:-$HOME/local}
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}
ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
SPHBOSON_DIR=${SPHBOSON_DIR:-$ROTBOSON_DIR/sphboson}
VALIDATION_ROOT=${VALIDATION_ROOT:-$ROTBOSON_DIR/validation/results}
SCAN_DIR=$VALIDATION_ROOT/l0/free_sequence
PHI0_VALUES=(${PHI0_VALUES:-0.005 0.0075 0.010 0.015 0.020 0.030 0.040 0.060 0.080 0.100 0.150 0.200 0.300 0.400})
source "$SPHBOSON_DIR/hpc/run_sequence_lib.sh"
mkdir -p "$SCAN_DIR"
status_file="$SCAN_DIR/run_status.csv"
for phi0 in "${PHI0_VALUES[@]}"; do
  label="free_l0_phi0_$(label_for_value "$phi0")"
  if [ -f "$status_file" ] && env -u LD_LIBRARY_PATH /usr/bin/awk -F, -v label="$label" '$1 == label && $6 == 0 {found=1} END {exit !found}' "$status_file"; then
    echo "Reusing completed l=0 checkpoint $label"
    continue
  fi
  if ! run_single_phi0 "$SPHBOSON_DIR" free none 0.0 "$SCAN_DIR" "$label" "$phi0"; then
    echo "WARNING: $label failed; continuing with the remaining amplitudes" >&2
  fi
done
