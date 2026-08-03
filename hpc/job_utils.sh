#!/bin/bash

cleanup_old_slurm_logs() {
  local log_prefix="$1"
  local log_dir="${2:-$PWD}"

  if [ -n "${SLURM_JOB_ID:-}" ]; then
    find "$log_dir" -maxdepth 1 -type f \( \
      -name "${log_prefix}_*.out" -o -name "${log_prefix}_*.err" \
    \) ! -name "${log_prefix}_${SLURM_JOB_ID}.out" \
       ! -name "${log_prefix}_${SLURM_JOB_ID}.err" -delete
  else
    find "$log_dir" -maxdepth 1 -type f \( \
      -name "${log_prefix}_*.out" -o -name "${log_prefix}_*.err" \
    \) -delete
  fi
}
