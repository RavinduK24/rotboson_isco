#!/bin/bash

#SBATCH --job-name=rotboson_sextic
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_sextic_%j.out
#SBATCH --error=rotboson_sextic_%j.err

set -euo pipefail

export MKLROOT=$HOME/intel/mkl/2024.1
export LIBCONFIGROOT=$HOME/local
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

ROTBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON
RUN_DIR=$ROTBOSON_DIR/out
BASE_PAR=$ROTBOSON_DIR/examples/sextic.par
SCAN_DIR=$RUN_DIR/hpc_sextic_lambda_6_scan
COUPLING_VALUES=("0.0" "1.0e-4" "1.0e-3" "1.0e-2" "1.0e-1" "1.0" "10.0")

mkdir -p "$SCAN_DIR/params"
cd "$RUN_DIR"

for LAMBDA in "${COUPLING_VALUES[@]}"; do
  LABEL=$(printf "%s" "$LAMBDA" | sed 's/+//g; s/-/m/g; s/\./p/g')
  PAR_FILE=$SCAN_DIR/params/sextic_lambda_6_${LABEL}.par

  awk -v lambda="$LAMBDA" '
    /^potential[[:space:]]*=/ { print "potential = \"sextic\""; next }
    /^lambda_6[[:space:]]*=/ { print "lambda_6 = " lambda; next }
    { print }
  ' "$BASE_PAR" > "$PAR_FILE"

  echo "============================================================"
  echo "Running sextic lambda_6=$LAMBDA"
  echo "START_TIME=$(date -Is)"
  "$ROTBOSON_DIR/ROTBOSON" "$PAR_FILE"
  echo "END_TIME=$(date -Is)"
done
