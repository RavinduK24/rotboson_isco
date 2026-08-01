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
  local template="$sphboson_dir/out/l0_production.par"
  local parameter_file="$scan_dir/params/${label}.par"

  mkdir -p "$scan_dir/params"
  if [ "$potential" = "free" ]; then
    sed 's/^potential = .*/potential = "free"/' "$template" > "$parameter_file"
  else
    sed \
      -e "s/^potential = .*/potential = \"$potential\"/" \
      -e "s/^${coupling_name} = .*/${coupling_name} = ${coupling_value}/" \
      "$template" > "$parameter_file"
  fi
  printf "%s\n" "$parameter_file"
}

run_sequence() {
  local sphboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local scan_dir="$5"
  local label="$6"
  local parameter_file

  parameter_file=$(write_sequence_params "$sphboson_dir" "$potential" \
    "$coupling_name" "$coupling_value" "$scan_dir" "$label")
  mkdir -p "$scan_dir/solutions"

  echo "Parameter file: $parameter_file"
  echo "Solution root: $scan_dir/solutions"
  echo "START_SEQUENCE=$(date -Is)"
  cd "$scan_dir/solutions"
  "$sphboson_dir/SPHBOSON" "$parameter_file"
  echo "END_SEQUENCE=$(date -Is)"
}
