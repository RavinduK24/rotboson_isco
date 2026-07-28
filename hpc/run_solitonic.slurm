#!/bin/bash

#SBATCH --job-name=rotboson_solitonic
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_solitonic_%j.out
#SBATCH --error=rotboson_solitonic_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out
SCAN_DIR=$RUN_DIR/hpc_solitonic_sigma_soliton_scan
COUPLING_VALUES=("100.0" "30.0" "10.0" "3.0" "1.0" "0.3")

mkdir -p "$SCAN_DIR/params"
cd "$RUN_DIR"
source "$ROTBOSON_DIR/hpc/run_sequence_lib.sh"

for SIGMA in "${COUPLING_VALUES[@]}"; do
  LABEL="solitonic_sigma_soliton_$(label_for_value "$SIGMA")"

  echo "============================================================"
  echo "Running production solitonic sequence sigma_soliton=$SIGMA"
  echo "START_TIME=$(date -Is)"
  run_sequence "$ROTBOSON_DIR" "solitonic" "sigma_soliton" "$SIGMA" "$SCAN_DIR" "$LABEL"
  echo "END_TIME=$(date -Is)"
done
