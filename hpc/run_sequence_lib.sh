#!/bin/bash

set -euo pipefail

label_for_value() {
  printf "%s" "$1" | sed 's/+//g; s/-/m/g; s/\./p/g'
}

coupling_tag() {
  local potential="$1"
  local coupling_name="$2"
  local coupling_value="$3"

  if [ "$potential" = "free" ]; then
    printf "pot=free"
  else
    printf "pot=%s,%s=%.5E" "$potential" "$coupling_name" "$coupling_value"
  fi
}

write_sequence_params() {
  local rotboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local scan_dir="$5"
  local label="$6"

  local seed_template="$rotboson_dir/out/l1_from_scratch.par"
  local cont_template="$rotboson_dir/out/l1_from_initial_data.par"
  local seed_par="$scan_dir/params/${label}_seed.par"
  local cont_par="$scan_dir/params/${label}_continue.par"
  local tag
  local seed_dir

  tag=$(coupling_tag "$potential" "$coupling_name" "$coupling_value")
  seed_dir="${tag},l=1,w=9.50000E-01,dr=6.25000E-02,N=0256"

  mkdir -p "$scan_dir/params"

  cp "$seed_template" "$seed_par"
  {
    printf "\n# HPC generated potential settings\n"
    printf "potential = \"%s\"\n" "$potential"
    if [ "$potential" != "free" ]; then
      printf "%s = %s\n" "$coupling_name" "$coupling_value"
    fi
  } >> "$seed_par"

  sed "s|l=1,w=9.50000E-01,dr=6.25000E-02,N=0256|$seed_dir|g" "$cont_template" > "$cont_par"
  {
    printf "\n# HPC generated potential settings\n"
    printf "potential = \"%s\"\n" "$potential"
    if [ "$potential" != "free" ]; then
      printf "%s = %s\n" "$coupling_name" "$coupling_value"
    fi
  } >> "$cont_par"

  printf "%s\n%s\n%s\n" "$seed_par" "$cont_par" "$seed_dir"
}

run_sequence() {
  local rotboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local scan_dir="$5"
  local label="$6"
  local generated
  local seed_par
  local cont_par
  local seed_dir

  generated=$(write_sequence_params "$rotboson_dir" "$potential" "$coupling_name" "$coupling_value" "$scan_dir" "$label")
  seed_par=$(printf "%s" "$generated" | sed -n '1p')
  cont_par=$(printf "%s" "$generated" | sed -n '2p')
  seed_dir=$(printf "%s" "$generated" | sed -n '3p')

  echo "Seed parameter: $seed_par"
  echo "Continuation parameter: $cont_par"
  echo "Expected seed directory: $seed_dir"

  echo "START_SEED=$(date -Is)"
  "$rotboson_dir/ROTBOSON" "$seed_par"
  echo "END_SEED=$(date -Is)"

  if [ ! -d "$seed_dir" ]; then
    echo "ERROR: expected seed directory was not created: $seed_dir" >&2
    exit 1
  fi

  echo "START_CONTINUATION=$(date -Is)"
  "$rotboson_dir/ROTBOSON" "$cont_par"
  echo "END_CONTINUATION=$(date -Is)"
}
