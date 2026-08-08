#!/bin/bash

cleanup_old_slurm_logs() {
  local log_prefix="$1"
  local log_dir="${2:-$PWD}"
  local current_job="${SLURM_ARRAY_JOB_ID:-${SLURM_JOB_ID:-}}"

  if [ -n "$current_job" ] && [ -n "${SLURM_ARRAY_JOB_ID:-}" ]; then
    find "$log_dir" -maxdepth 1 -type f \( \
      -name "${log_prefix}_*.out" -o -name "${log_prefix}_*.err" \
    \) ! -name "${log_prefix}_${current_job}_*.out" \
       ! -name "${log_prefix}_${current_job}_*.err" -delete
  elif [ -n "$current_job" ]; then
    find "$log_dir" -maxdepth 1 -type f \( \
      -name "${log_prefix}_*.out" -o -name "${log_prefix}_*.err" \
    \) ! -name "${log_prefix}_${current_job}.out" \
       ! -name "${log_prefix}_${current_job}.err" -delete
  else
    find "$log_dir" -maxdepth 1 -type f \( \
      -name "${log_prefix}_*.out" -o -name "${log_prefix}_*.err" \
    \) -delete
  fi
}
