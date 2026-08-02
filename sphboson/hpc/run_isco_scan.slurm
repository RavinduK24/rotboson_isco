#!/bin/bash

#SBATCH --job-name=sphboson_isco_l0
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=sphboson_isco_l0_%j.out
#SBATCH --error=sphboson_isco_l0_%j.err

set -euo pipefail

module load Anaconda3/2023.03-1

SPHBOSON_DIR=${SPHBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON/sphboson}
ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
INPUT_ROOT=${INPUT_ROOT:-$SPHBOSON_DIR/out}
OUTPUT_DIR=${OUTPUT_DIR:-$SPHBOSON_DIR/results/isco_l0}

mkdir -p "$OUTPUT_DIR"
PYTHONDONTWRITEBYTECODE=1 python "$ROTBOSON_DIR/scripts/rotboson_isco.py" \
  "$INPUT_ROOT" --output-dir "$OUTPUT_DIR" --export-profiles --strict
