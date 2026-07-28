#!/bin/bash

#SBATCH --job-name=rotboson_axion
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_axion_%j.out
#SBATCH --error=rotboson_axion_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out
SCAN_DIR=$RUN_DIR/hpc_axion_f_axion_scan
COUPLING_VALUES=("100.0" "30.0" "10.0" "3.0" "1.0" "0.3")

mkdir -p "$SCAN_DIR/params"
cd "$RUN_DIR"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"

for FAXION in "${COUPLING_VALUES[@]}"; do
  LABEL="axion_f_axion_$(label_for_value "$FAXION")"

  echo "============================================================"
  echo "Running production axion sequence f_axion=$FAXION"
  echo "START_TIME=$(date -Is)"
  run_sequence "$ROTBOSON_DIR" "axion" "f_axion" "$FAXION" "$SCAN_DIR" "$LABEL"
  echo "END_TIME=$(date -Is)"
done
