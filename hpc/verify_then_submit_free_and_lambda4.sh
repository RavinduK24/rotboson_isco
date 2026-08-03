#!/bin/bash

set -euo pipefail

cd "${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}"

build_job=$(sbatch --parsable hpc/run_build.slurm)
echo "Submitted build/test job: $build_job"

dry_free_job=$(sbatch --parsable --dependency=afterok:"$build_job" hpc/run_dry_free.slurm)
echo "Submitted dry free-field smoke test after build success: $dry_free_job"

dry_quartic_job=$(sbatch --parsable --dependency=afterok:"$dry_free_job" hpc/run_dry_quartic_lambda4.slurm)
echo "Submitted dry quartic Lambda=200 smoke test after dry free success: $dry_quartic_job"

cleanup_job=$(sbatch --parsable --dependency=afterok:"$dry_quartic_job" hpc/run_cleanup_dry_test.slurm)
echo "Submitted dry-test cleanup after dry quartic success: $cleanup_job"

free_job=$(sbatch --parsable --dependency=afterok:"$cleanup_job" hpc/run_free.slurm)
echo "Submitted free-field production scan after cleanup success: $free_job"

quartic_job=$(sbatch --parsable --dependency=afterok:"$free_job" hpc/run_quartic.slurm)
echo "Submitted quartic Lambda=200 production scan after free-field success: $quartic_job"
