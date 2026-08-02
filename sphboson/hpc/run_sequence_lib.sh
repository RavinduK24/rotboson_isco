#!/bin/bash

set -euo pipefail

label_for_value() {
  printf "%s" "$1" | sed 's/+//g; s/-/m/g; s/\./p/g'
}

write_sequence_params() {
  local sphboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local scan_dir="$5"
  local label="$6"
  local phi0="$7"
  local template="$sphboson_dir/out/l0_production.par"
  local parameter_file="$scan_dir/params/${label}.par"

  mkdir -p "$scan_dir/params"
  if [ "$potential" = "free" ]; then
    sed \
      -e 's/^potential = .*/potential = "free"/' \
      -e "s/^phi0 = .*/phi0 = ${phi0}/" \
      -e 's/^scale_next = .*/scale_next = 1.0/' \
      -e 's/^w_min = .*/w_min = 0.999999/' \
      "$template" > "$parameter_file"
  else
    sed \
      -e "s/^potential = .*/potential = \"$potential\"/" \
      -e "s/^${coupling_name} = .*/${coupling_name} = ${coupling_value}/" \
      -e "s/^phi0 = .*/phi0 = ${phi0}/" \
      -e 's/^scale_next = .*/scale_next = 1.0/' \
      -e 's/^w_min = .*/w_min = 0.999999/' \
      "$template" > "$parameter_file"
  fi
  printf "%s\n" "$parameter_file"
}

run_single_phi0() {
  local sphboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local scan_dir="$5"
  local label="$6"
  local phi0="$7"
  local parameter_file
  local solution_dir="$scan_dir/solutions/$label"
  local status_file="$scan_dir/run_status.tsv"

  parameter_file=$(write_sequence_params "$sphboson_dir" "$potential" \
    "$coupling_name" "$coupling_value" "$scan_dir" "$label" "$phi0")
  mkdir -p "$solution_dir"
  if [ ! -f "$status_file" ]; then
    printf "label\tpotential\tcoupling_name\tcoupling_value\tphi0\texit_code\n" > "$status_file"
  fi

  echo "Parameter file: $parameter_file"
  echo "phi0=$phi0"
  echo "Solution root: $solution_dir"
  echo "START_SINGLE=$(date -Is)"
  set +e
  (
    cd "$solution_dir"
    "$sphboson_dir/SPHBOSON" "$parameter_file"
  )
  local exit_code=$?
  set -e
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$label" "$potential" "$coupling_name" \
    "$coupling_value" "$phi0" "$exit_code" >> "$status_file"
  echo "END_SINGLE=$(date -Is)"
  return "$exit_code"
}

run_phi0_scan() {
  local sphboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local scan_dir="$5"
  local label_prefix="$6"
  shift 6
  local phi0
  local label

  for phi0 in "$@"; do
    label="${label_prefix}_phi0_$(label_for_value "$phi0")"
    if ! run_single_phi0 "$sphboson_dir" "$potential" "$coupling_name" \
      "$coupling_value" "$scan_dir" "$label" "$phi0"; then
      echo "WARNING: $label failed; continuing with next phi0." >&2
    fi
  done
}
