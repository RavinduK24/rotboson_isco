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
  local ell="${7:-1}"

  local seed_template="$rotboson_dir/out/l1_from_scratch.par"
  local cont_template="$rotboson_dir/out/l1_from_initial_data.par"
  local seed_par="$scan_dir/params/${label}_seed.par"
  local cont_par="$scan_dir/params/${label}_continue.par"
  local tag
  local seed_dir

  tag=$(coupling_tag "$potential" "$coupling_name" "$coupling_value")
  seed_dir="${tag},l=${ell},w=9.50000E-01,dr=6.25000E-02,N=0256"

  mkdir -p "$scan_dir/params"

  sed -E "s/^[[:space:]]*l[[:space:]]*=.*/l = ${ell}/" "$seed_template" > "$seed_par"
  {
    printf "\n# HPC generated potential settings\n"
    printf "potential = \"%s\"\n" "$potential"
    if [ "$potential" != "free" ]; then
      printf "%s = %s\n" "$coupling_name" "$coupling_value"
    fi
    printf "max_initial_guess_checks = 8\n"
    printf "norm_f0_target = 1.0E-5\n"
    printf "rr_phi_max_minimum = 1.0\n"
    printf "rr_phi_max_maximum = 16.0\n"
  } >> "$seed_par"

  sed -E "s/^[[:space:]]*l[[:space:]]*=.*/l = ${ell}/" "$cont_template" \
    | sed "s|l=1,w=9.50000E-01,dr=6.25000E-02,N=0256|$seed_dir|g" > "$cont_par"
  {
    printf "\n# HPC generated potential settings\n"
    printf "potential = \"%s\"\n" "$potential"
    if [ "$potential" != "free" ]; then
      printf "%s = %s\n" "$coupling_name" "$coupling_value"
    fi
    printf "max_initial_guess_checks = 8\n"
    printf "norm_f0_target = 1.0E-5\n"
    printf "rr_phi_max_minimum = 1.0\n"
    printf "rr_phi_max_maximum = 16.0\n"
  } >> "$cont_par"

  printf "%s\n%s\n%s\n" "$seed_par" "$cont_par" "$seed_dir"
}

cleanup_sequence_outputs() {
  local rotboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local ell="${5:-1}"
  local tag

  tag=$(coupling_tag "$potential" "$coupling_name" "$coupling_value")
  echo "Cleaning old outputs for ${tag},l=${ell}"
  find "$rotboson_dir/out" -maxdepth 1 -type d \
    -name "${tag},l=${ell},w=*,dr=6.25000E-02,N=0256*" -exec rm -rf {} +
  find "$rotboson_dir/out" -maxdepth 1 -type d \
    -name "l=${ell},w=*,dr=6.25000E-02,N=0256*" -exec rm -rf {} +
  find "$rotboson_dir/out" -maxdepth 1 -type d \
    -name "interrupted_*_l=${ell},w=*,dr=6.25000E-02,N=0256*" -exec rm -rf {} +
}

run_sequence() {
  local rotboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local scan_dir="$5"
  local label="$6"
  local ell="${7:-1}"
  local generated
  local seed_par
  local cont_par
  local seed_dir

  if [ "${CLEAN_OLD_DATA:-1}" = "1" ]; then
    cleanup_sequence_outputs "$rotboson_dir" "$potential" "$coupling_name" "$coupling_value" "$ell"
  fi

  generated=$(write_sequence_params "$rotboson_dir" "$potential" "$coupling_name" "$coupling_value" "$scan_dir" "$label" "$ell")
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
