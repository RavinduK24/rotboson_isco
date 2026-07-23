#!/bin/bash

#SBATCH --job-name=rotboson_kkls
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_kkls_%j.out
#SBATCH --error=rotboson_kkls_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out
BASE_PAR=$ROTBOSON_DIR/examples/kkls.par
SCAN_DIR=$RUN_DIR/hpc_kkls_kappa_kkls_scan
COUPLING_VALUES=("100.0" "30.0" "10.0" "3.0" "1.0" "0.3")

mkdir -p "$SCAN_DIR/params"
cd "$RUN_DIR"

for KAPPA in "${COUPLING_VALUES[@]}"; do
  LABEL=$(printf "%s" "$KAPPA" | sed 's/+//g; s/-/m/g; s/\./p/g')
  PAR_FILE=$SCAN_DIR/params/kkls_kappa_kkls_${LABEL}.par

  awk -v value="$KAPPA" '
    /^potential[[:space:]]*=/ { print "potential = \"kkls\""; next }
    /^kappa_kkls[[:space:]]*=/ { print "kappa_kkls = " value; next }
    { print }
  ' "$BASE_PAR" > "$PAR_FILE"

  echo "============================================================"
  echo "Running kkls kappa_kkls=$KAPPA"
  echo "START_TIME=$(date -Is)"
  "$ROTBOSON_DIR/ROTBOSON" "$PAR_FILE"
  echo "END_TIME=$(date -Is)"
done
