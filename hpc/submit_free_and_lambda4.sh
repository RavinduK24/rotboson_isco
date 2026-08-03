#!/bin/bash

set -euo pipefail

cd "${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}"

free_job=$(sbatch --parsable hpc/run_free.slurm)
echo "Submitted free-field scan: $free_job"

quartic_job=$(sbatch --parsable --dependency=afterok:"$free_job" hpc/run_quartic.slurm)
echo "Submitted quartic Lambda=200 scan after free-field success: $quartic_job"
