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

  parameter_file=$(write_sequence_params "$sphboson_dir" "$potential" \
    "$coupling_name" "$coupling_value" "$scan_dir" "$label" "$phi0")
  mkdir -p "$scan_dir/solutions"

  echo "Parameter file: $parameter_file"
  echo "phi0=$phi0"
  echo "Solution root: $scan_dir/solutions"
  echo "START_SINGLE=$(date -Is)"
  cd "$scan_dir/solutions"
  "$sphboson_dir/SPHBOSON" "$parameter_file"
  echo "END_SINGLE=$(date -Is)"
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
    run_single_phi0 "$sphboson_dir" "$potential" "$coupling_name" \
      "$coupling_value" "$scan_dir" "$label" "$phi0"
  done
}
