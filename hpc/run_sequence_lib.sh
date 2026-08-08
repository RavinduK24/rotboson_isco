#!/bin/bash

set -euo pipefail

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

set_ell_numerics() {
  local ell="$1"

  PROD_N=256
  PROD_EPSILON=1.0E-10
  PROD_MAX_NEWTON=50
  PROD_LAMBDA_MIN=1.0E-06

  case "$ell" in
    1)
      PROD_PSI0=1.000E-02
      PROD_DR=6.25000E-02
      PROD_RR_MAX=16.0
      PROD_SCALE_NEXT=1.03
      ;;
    2)
      PROD_PSI0=2.060E-03
      PROD_DR=6.25000E-02
      PROD_RR_MAX=16.0
      PROD_SCALE_NEXT=1.025
      ;;
    3)
      PROD_PSI0=3.270E-04
      PROD_DR=1.25000E-01
      PROD_RR_MAX=32.0
      PROD_SCALE_NEXT=1.02
      ;;
    4)
      PROD_PSI0=4.380E-05
      PROD_DR=1.25000E-01
      PROD_RR_MAX=32.0
      PROD_SCALE_NEXT=1.015
      ;;
    *)
      echo "ERROR: unsupported production l=$ell; expected 1, 2, 3, or 4" >&2
      return 1
      ;;
  esac
}

solution_family_pattern() {
  local potential="$1"
  local coupling_name="$2"
  local coupling_value="$3"
  local ell="$4"
  local tag

  tag=$(coupling_tag "$potential" "$coupling_name" "$coupling_value")
  printf "%s,l=%s,w=*" "$tag" "$ell"
}

weak_seed_dir() {
  local potential="$1"
  local coupling_name="$2"
  local coupling_value="$3"
  local ell="$4"
  local tag

  set_ell_numerics "$ell"
  tag=$(coupling_tag "$potential" "$coupling_name" "$coupling_value")
  printf "%s,l=%s,w=9.50000E-01,dr=%.5E,N=%04d" \
    "$tag" "$ell" "$PROD_DR" "$PROD_N"
}

append_generated_settings() {
  local parameter_file="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"

  {
    printf "\n# HPC generated potential and sweep guards\n"
    printf "potential = \"%s\"\n" "$potential"
    if [ "$potential" != "free" ]; then
      printf "%s = %s\n" "$coupling_name" "$coupling_value"
    fi
    printf "max_initial_guess_checks = 8\n"
    printf "norm_f0_target = 1.0E-5\n"
    printf "rr_phi_max_minimum = 1.0\n"
    printf "rr_phi_max_maximum = %s\n" "$PROD_RR_MAX"
  } >> "$parameter_file"
}

write_seed_params() {
  local rotboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local parameter_file="$5"
  local ell="$6"
  local template="$rotboson_dir/out/l1_from_scratch.par"

  set_ell_numerics "$ell"
  mkdir -p "$(dirname "$parameter_file")"
  sed -E \
    -e "s/^[[:space:]]*dr[[:space:]]*=.*/dr = ${PROD_DR}/" \
    -e "s/^[[:space:]]*dz[[:space:]]*=.*/dz = ${PROD_DR}/" \
    -e "s/^[[:space:]]*NrInterior[[:space:]]*=.*/NrInterior = ${PROD_N}/" \
    -e "s/^[[:space:]]*NzInterior[[:space:]]*=.*/NzInterior = ${PROD_N}/" \
    -e "s/^[[:space:]]*l[[:space:]]*=.*/l = ${ell}/" \
    -e "s/^[[:space:]]*psi0[[:space:]]*=.*/psi0 = ${PROD_PSI0}/" \
    -e "s/^[[:space:]]*epsilon[[:space:]]*=.*/epsilon = ${PROD_EPSILON}/" \
    -e "s/^[[:space:]]*maxNewtonIter[[:space:]]*=.*/maxNewtonIter = ${PROD_MAX_NEWTON}/" \
    -e "s/^[[:space:]]*lambdaMin[[:space:]]*=.*/lambdaMin = ${PROD_LAMBDA_MIN}/" \
    "$template" > "$parameter_file"
  append_generated_settings "$parameter_file" "$potential" "$coupling_name" "$coupling_value"
}

write_initial_data_params() {
  local rotboson_dir="$1"
  local source_dir="$2"
  local potential="$3"
  local coupling_name="$4"
  local coupling_value="$5"
  local parameter_file="$6"
  local ell="$7"
  local scale_u4="$8"
  local sweep="$9"
  local scale_next="${10}"
  local template="$rotboson_dir/out/l1_from_initial_data.par"

  set_ell_numerics "$ell"
  mkdir -p "$(dirname "$parameter_file")"
  sed -E \
    -e "s/^[[:space:]]*dr[[:space:]]*=.*/dr = ${PROD_DR}/" \
    -e "s/^[[:space:]]*dz[[:space:]]*=.*/dz = ${PROD_DR}/" \
    -e "s/^[[:space:]]*NrInterior[[:space:]]*=.*/NrInterior = ${PROD_N}/" \
    -e "s/^[[:space:]]*NzInterior[[:space:]]*=.*/NzInterior = ${PROD_N}/" \
    -e "s|^[[:space:]]*log_alpha_i[[:space:]]*=.*|log_alpha_i = \"${source_dir}/log_alpha_f.asc\"|" \
    -e "s|^[[:space:]]*beta_i[[:space:]]*=.*|beta_i = \"${source_dir}/beta_f.asc\"|" \
    -e "s|^[[:space:]]*log_h_i[[:space:]]*=.*|log_h_i = \"${source_dir}/log_h_f.asc\"|" \
    -e "s|^[[:space:]]*log_a_i[[:space:]]*=.*|log_a_i = \"${source_dir}/log_a_f.asc\"|" \
    -e "s|^[[:space:]]*psi_i[[:space:]]*=.*|psi_i = \"${source_dir}/psi_f.asc\"|" \
    -e "s|^[[:space:]]*lambda_i[[:space:]]*=.*|lambda_i = \"${source_dir}/lambda_f.asc\"|" \
    -e "s|^[[:space:]]*w_i[[:space:]]*=.*|w_i = \"${source_dir}/w_f.asc\"|" \
    -e "s/^[[:space:]]*scale_u4[[:space:]]*=.*/scale_u4 = ${scale_u4}/" \
    -e "s/^[[:space:]]*l[[:space:]]*=.*/l = ${ell}/" \
    -e "s/^[[:space:]]*sweep[[:space:]]*=.*/sweep = ${sweep}/" \
    -e "s/^[[:space:]]*scale_next[[:space:]]*=.*/scale_next = ${scale_next}/" \
    -e "s/^[[:space:]]*epsilon[[:space:]]*=.*/epsilon = ${PROD_EPSILON}/" \
    -e "s/^[[:space:]]*maxNewtonIter[[:space:]]*=.*/maxNewtonIter = ${PROD_MAX_NEWTON}/" \
    -e "s/^[[:space:]]*lambdaMin[[:space:]]*=.*/lambdaMin = ${PROD_LAMBDA_MIN}/" \
    "$template" > "$parameter_file"
  append_generated_settings "$parameter_file" "$potential" "$coupling_name" "$coupling_value"
}

metadata_value() {
  local directory="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key {print $2; exit}' "$directory/run_metadata.txt"
}

first_numeric_value() {
  awk '!/^#/ && NF {print $1; exit}' "$1"
}

validate_solution() {
  local directory="$1"
  local status
  local mass
  local phi_max

  if [ ! -d "$directory" ] || [ ! -f "$directory/run_metadata.txt" ] || [ ! -f "$directory/phi_max.asc" ]; then
    echo "ERROR: incomplete solution directory: $directory" >&2
    return 1
  fi
  status=$(metadata_value "$directory" "convergence_status")
  mass=$(metadata_value "$directory" "M_Komar")
  phi_max=$(first_numeric_value "$directory/phi_max.asc")
  if [ "$status" != "converged" ]; then
    echo "ERROR: solver did not converge in $directory" >&2
    return 1
  fi
  if ! awk -v mass="$mass" -v phi="$phi_max" 'BEGIN {exit !(mass > 1.0e-10 && phi > 1.0e-10)}'; then
    echo "ERROR: vacuum-like solution rejected: $directory (M=$mass, phi_max=$phi_max)" >&2
    return 1
  fi
}

validate_continuation_step() {
  local previous="$1"
  local current="$2"
  local previous_mass
  local current_mass
  local previous_phi
  local current_phi

  validate_solution "$previous"
  validate_solution "$current"
  previous_mass=$(metadata_value "$previous" "M_Komar")
  current_mass=$(metadata_value "$current" "M_Komar")
  previous_phi=$(first_numeric_value "$previous/phi_max.asc")
  current_phi=$(first_numeric_value "$current/phi_max.asc")
  if ! awk -v pm="$previous_mass" -v cm="$current_mass" -v pp="$previous_phi" -v cp="$current_phi" \
      'BEGIN {exit !(cm > pm * 1.0e-4 && cp > pp * 1.0e-4)}'; then
    echo "ERROR: continuation collapsed toward vacuum: $previous -> $current" >&2
    return 1
  fi
}

remove_solution_family() {
  local rotboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local ell="$5"
  local pattern

  pattern=$(solution_family_pattern "$potential" "$coupling_name" "$coupling_value" "$ell")
  find "$rotboson_dir/out" -maxdepth 1 -type d -name "$pattern" -exec rm -rf {} +
}

remove_all_potential_solutions_for_ell() {
  local rotboson_dir="$1"
  local potential="$2"
  local ell="$3"

  find "$rotboson_dir/out" -maxdepth 1 -type d \
    -name "pot=${potential}*,l=${ell},w=*" -exec rm -rf {} +
}

find_valid_solution() {
  local rotboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local ell="$5"
  local pattern
  local directory

  pattern=$(solution_family_pattern "$potential" "$coupling_name" "$coupling_value" "$ell")
  while IFS= read -r directory; do
    if validate_solution "$directory"; then
      basename "$directory"
      return 0
    fi
  done < <(find "$rotboson_dir/out" -maxdepth 1 -type d -name "$pattern" -print | sort -r)
  echo "ERROR: no valid solution found for $pattern" >&2
  return 1
}

count_converged_solutions() {
  local rotboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local ell="$5"
  local pattern
  local directory
  local count=0

  pattern=$(solution_family_pattern "$potential" "$coupling_name" "$coupling_value" "$ell")
  while IFS= read -r directory; do
    if validate_solution "$directory" >/dev/null 2>&1; then
      count=$((count + 1))
    fi
  done < <(find "$rotboson_dir/out" -maxdepth 1 -type d -name "$pattern" -print)
  printf "%d" "$count"
}

find_lowest_omega_solution() {
  local rotboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local ell="$5"
  local pattern
  local directory
  local omega

  pattern=$(solution_family_pattern "$potential" "$coupling_name" "$coupling_value" "$ell")
  while IFS= read -r directory; do
    if validate_solution "$directory" >/dev/null 2>&1; then
      omega=$(metadata_value "$directory" "omega")
      printf "%s %s\n" "$omega" "$(basename "$directory")"
    fi
  done < <(find "$rotboson_dir/out" -maxdepth 1 -type d -name "$pattern" -print) \
    | sort -g | awk 'NR == 1 {print $2}'
}

branch_has_internal_mass_maximum() {
  local rotboson_dir="$1"
  local potential="$2"
  local coupling_name="$3"
  local coupling_value="$4"
  local ell="$5"
  local pattern
  local directory
  local omega
  local mass

  pattern=$(solution_family_pattern "$potential" "$coupling_name" "$coupling_value" "$ell")
  while IFS= read -r directory; do
    if validate_solution "$directory" >/dev/null 2>&1; then
      omega=$(metadata_value "$directory" "omega")
      mass=$(metadata_value "$directory" "M_Komar")
      printf "%s %s\n" "$omega" "$mass"
    fi
  done < <(find "$rotboson_dir/out" -maxdepth 1 -type d -name "$pattern" -print) \
    | sort -g \
    | awk '
        NR == 1 {maximum = $2; maximum_index = 1}
        $2 > maximum {maximum = $2; maximum_index = NR}
        END {exit !(NR >= 3 && maximum_index > 1 && maximum_index < NR)}
      '
}

run_free_sequence() {
  local rotboson_dir="$1"
  local scan_dir="$2"
  local ell="$3"
  local seed_parameter="$scan_dir/params/free_l${ell}_seed.par"
  local branch_parameter="$scan_dir/params/free_l${ell}_branch.par"
  local state_dir="$scan_dir/state"
  local initialized="$state_dir/initialized"
  local completed="$state_dir/completed"
  local seed_dir
  local resume_dir
  local count

  set_ell_numerics "$ell"
  seed_dir=$(weak_seed_dir "free" "none" "0.0" "$ell")
  if [ "${RESET_FREE:-0}" = "1" ]; then
    rm -rf "$state_dir"
  fi
  if [ ! -f "$initialized" ]; then
    remove_all_potential_solutions_for_ell "$rotboson_dir" "free" "$ell"
    mkdir -p "$state_dir"
    write_seed_params "$rotboson_dir" "free" "none" "0.0" "$seed_parameter" "$ell"
    echo "Running free weak seed l=$ell, psi0=$PROD_PSI0, dr=$PROD_DR"
    "$rotboson_dir/ROTBOSON" "$seed_parameter"
    validate_solution "$seed_dir"
    printf "initialized=%s\n" "$(date -Is)" > "$initialized"
  fi
  validate_solution "$seed_dir"
  if [ -f "$completed" ]; then
    if branch_has_internal_mass_maximum "$rotboson_dir" "free" "none" "0.0" "$ell"; then
      echo "Free l=$ell branch already completed"
      return 0
    fi
    rm -f "$completed"
  fi

  resume_dir=$(find_lowest_omega_solution "$rotboson_dir" "free" "none" "0.0" "$ell")
  if [ -z "$resume_dir" ]; then
    resume_dir=$seed_dir
  fi
  write_initial_data_params "$rotboson_dir" "$resume_dir" "free" "none" "0.0" \
    "$branch_parameter" "$ell" "$PROD_SCALE_NEXT" 1 "$PROD_SCALE_NEXT"
  echo "Running free amplitude branch l=$ell from $resume_dir, scale_next=$PROD_SCALE_NEXT"
  "$rotboson_dir/ROTBOSON" "$branch_parameter"
  count=$(count_converged_solutions "$rotboson_dir" "free" "none" "0.0" "$ell")
  if [ "$count" -lt 2 ]; then
    echo "ERROR: free l=$ell produced only $count converged solution(s)" >&2
    return 1
  fi
  if ! branch_has_internal_mass_maximum "$rotboson_dir" "free" "none" "0.0" "$ell"; then
    echo "ERROR: free l=$ell has not crossed an internal mass maximum; resubmit this array task to continue" >&2
    return 1
  fi
  printf "completed=%s\n" "$(date -Is)" > "$completed"
  echo "Free l=$ell complete with $count converged solutions"
}

run_homotopy_step() {
  local rotboson_dir="$1"
  local scan_dir="$2"
  local ell="$3"
  local previous_dir="$4"
  local paper_lambda="$5"
  local lambda4="$6"
  local checkpoint_dir="$scan_dir/checkpoints/l${ell}"
  local checkpoint="$checkpoint_dir/Lambda_${paper_lambda}.path"
  local parameter_file="$scan_dir/params/l${ell}_Lambda_${paper_lambda}.par"
  local current_dir

  mkdir -p "$checkpoint_dir" "$scan_dir/params"
  if [ -f "$checkpoint" ]; then
    current_dir=$(sed -n '1p' "$checkpoint")
    if validate_continuation_step "$previous_dir" "$current_dir"; then
      echo "Reusing checkpoint Lambda=$paper_lambda: $current_dir"
      HOMOTOPY_RESULT=$current_dir
      return 0
    fi
    rm -f "$checkpoint"
  fi

  remove_solution_family "$rotboson_dir" "quartic" "lambda_4" "$lambda4" "$ell"
  write_initial_data_params "$rotboson_dir" "$previous_dir" "quartic" "lambda_4" "$lambda4" \
    "$parameter_file" "$ell" 1.0 0 1.0
  echo "Continuing l=$ell: Lambda=$paper_lambda, lambda_4=$lambda4"
  "$rotboson_dir/ROTBOSON" "$parameter_file"
  current_dir=$(find_valid_solution "$rotboson_dir" "quartic" "lambda_4" "$lambda4" "$ell")
  validate_continuation_step "$previous_dir" "$current_dir"
  printf "%s\n" "$current_dir" > "$checkpoint"
  HOMOTOPY_RESULT=$current_dir
}

initialize_homotopy() {
  local rotboson_dir="$1"
  local scan_dir="$2"
  local ell="$3"
  local checkpoint_dir="$scan_dir/checkpoints/l${ell}"
  local marker="$checkpoint_dir/initialized"

  if [ "${RESET_HOMOTOPY:-0}" = "1" ]; then
    rm -rf "$checkpoint_dir"
  fi
  if [ ! -f "$marker" ]; then
    echo "Removing old quartic l=$ell outputs before the new homotopy"
    remove_all_potential_solutions_for_ell "$rotboson_dir" "quartic" "$ell"
    mkdir -p "$checkpoint_dir"
    printf "initialized=%s\n" "$(date -Is)" > "$marker"
  fi
}

homotopy_checkpoint() {
  local scan_dir="$1"
  local ell="$2"
  local paper_lambda="$3"
  local checkpoint="$scan_dir/checkpoints/l${ell}/Lambda_${paper_lambda}.path"
  local directory

  if [ ! -f "$checkpoint" ]; then
    echo "ERROR: missing homotopy checkpoint $checkpoint" >&2
    return 1
  fi
  directory=$(sed -n '1p' "$checkpoint")
  validate_solution "$directory"
  printf "%s" "$directory"
}

run_target_quartic_branch() {
  local rotboson_dir="$1"
  local scan_dir="$2"
  local ell="$3"
  local source_dir="$4"
  local target_lambda4=2513.2741228718345
  local parameter_file="$scan_dir/params/quartic_Lambda_200_l${ell}_branch.par"
  local state_dir="$scan_dir/state"
  local initialized="$state_dir/initialized"
  local completed="$state_dir/completed"
  local pattern
  local directory
  local resume_dir
  local count

  set_ell_numerics "$ell"
  if [ "${RESET_BRANCH:-0}" = "1" ]; then
    rm -rf "$state_dir"
  fi
  if [ ! -f "$initialized" ]; then
    pattern=$(solution_family_pattern "quartic" "lambda_4" "$target_lambda4" "$ell")
    while IFS= read -r directory; do
      if [ "$(basename "$directory")" != "$source_dir" ]; then
        rm -rf "$directory"
      fi
    done < <(find "$rotboson_dir/out" -maxdepth 1 -type d -name "$pattern" -print)
    mkdir -p "$state_dir"
    printf "initialized=%s\n" "$(date -Is)" > "$initialized"
  fi
  validate_solution "$source_dir"
  if [ -f "$completed" ]; then
    if branch_has_internal_mass_maximum "$rotboson_dir" "quartic" "lambda_4" "$target_lambda4" "$ell"; then
      echo "Lambda=200 l=$ell branch already completed"
      return 0
    fi
    rm -f "$completed"
  fi
  resume_dir=$(find_lowest_omega_solution "$rotboson_dir" "quartic" "lambda_4" "$target_lambda4" "$ell")
  if [ -z "$resume_dir" ]; then
    resume_dir=$source_dir
  fi
  write_initial_data_params "$rotboson_dir" "$resume_dir" "quartic" "lambda_4" "$target_lambda4" \
    "$parameter_file" "$ell" "$PROD_SCALE_NEXT" 1 "$PROD_SCALE_NEXT"
  echo "Running Lambda=200 amplitude branch l=$ell from $resume_dir, scale_next=$PROD_SCALE_NEXT"
  "$rotboson_dir/ROTBOSON" "$parameter_file"
  count=$(count_converged_solutions "$rotboson_dir" "quartic" "lambda_4" "$target_lambda4" "$ell")
  if [ "$count" -lt 2 ]; then
    echo "ERROR: Lambda=200 l=$ell produced only $count converged solution(s)" >&2
    return 1
  fi
  if ! branch_has_internal_mass_maximum "$rotboson_dir" "quartic" "lambda_4" "$target_lambda4" "$ell"; then
    echo "ERROR: Lambda=200 l=$ell has not crossed an internal mass maximum; resubmit this array task to continue" >&2
    return 1
  fi
  printf "completed=%s\n" "$(date -Is)" > "$completed"
  echo "Lambda=200 l=$ell complete with $count converged solutions"
}
