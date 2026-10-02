#!/bin/bash

#SBATCH --job-name=bsval_build
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=validation/results/logs/build_%j.out
#SBATCH --error=validation/results/logs/build_%j.err

set -euo pipefail

export MKLROOT=${MKLROOT:-$HOME/intel/mkl/2024.1}
export LIBCONFIGROOT=${LIBCONFIGROOT:-$HOME/local}
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}

ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
VALIDATION_ELL=${VALIDATION_ELL:-1}

if [ "$VALIDATION_ELL" = "0" ]; then
  cd "$ROTBOSON_DIR/sphboson"
  make clean
  make all compiler=gnu
  make test
else
  cd "$ROTBOSON_DIR"
  make clean
  make all compiler=gnu
  make test-potential
  make test-jacobian
  "${PYTHON_BIN:-python3}" -m unittest tests/test_literature_validation.py
  "${PYTHON_BIN:-python3}" -m unittest tests/test_rotboson_isco.py
fi
