#!/bin/bash

set -euo pipefail

HPC_VALIDATION_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

numeric_helper() {
  env LD_LIBRARY_PATH= /usr/bin/python3 "$HPC_VALIDATION_LIB_DIR/numeric_helper.py" "$@"
}

validation_python() {
  "${PYTHON_BIN:-python3}" "$ROTBOSON_DIR/scripts/validate_boson_stars.py" --manifest "$ROTBOSON_DIR/validation/benchmarks.json" "$@"
}

metadata_value() {
  local directory="$1"
  local key="$2"
  numeric_helper metadata "$directory/run_metadata.txt" "$key"
}

first_numeric_value() {
  numeric_helper first "$1"
}

validation_solution_from_pointer() {
  local pointer="$1"
  [ -s "$pointer" ] || return 1
  sed -n '1p' "$pointer"
}

validation_pointer_is_valid() {
  local pointer="$1"
  local target_id="${2:-}"
  local solution
  solution=$(validation_solution_from_pointer "$pointer") || return 1
  if [ -n "$target_id" ]; then
    validation_python check-solution --path "$solution" --target-id "$target_id" >/dev/null
  else
    validation_python check-solution --path "$solution" >/dev/null
  fi
}

write_validation_pointer() {
  local pointer="$1"
  local solution="$2"
  local temporary="${pointer}.tmp.$$"
  printf '%s\n' "$solution" > "$temporary"
  mv "$temporary" "$pointer"
}

write_analytic_seed_params() {
  local parameter_file="$1"
  local ell="$2"
  local n="$3"
  local r_max="$4"
  local omega="$5"
  local psi0="$6"
  local dr
  dr=$(numeric_helper divide "$r_max" "$n")
  mkdir -p "$(dirname "$parameter_file")"
  sed -E \
    -e "s/^[[:space:]]*dr[[:space:]]*=.*/dr = ${dr}/" \
    -e "s/^[[:space:]]*dz[[:space:]]*=.*/dz = ${dr}/" \
    -e "s/^[[:space:]]*NrInterior[[:space:]]*=.*/NrInterior = ${n}/" \
    -e "s/^[[:space:]]*NzInterior[[:space:]]*=.*/NzInterior = ${n}/" \
    -e "s/^[[:space:]]*l[[:space:]]*=.*/l = ${ell}/" \
    -e "s/^[[:space:]]*psi0[[:space:]]*=.*/psi0 = ${psi0}/" \
    -e "s/^[[:space:]]*w0[[:space:]]*=.*/w0 = ${omega}/" \
    -e 's/^[[:space:]]*epsilon[[:space:]]*=.*/epsilon = 1.0E-10/' \
    -e 's/^[[:space:]]*maxNewtonIter[[:space:]]*=.*/maxNewtonIter = 50/' \
    -e 's/^[[:space:]]*lambdaMin[[:space:]]*=.*/lambdaMin = 1.0E-6/' \
    "$ROTBOSON_DIR/out/l1_from_scratch.par" > "$parameter_file"
  {
    echo 'potential = "free"'
    echo 'max_initial_guess_checks = 8'
    echo 'norm_f0_target = 1.0E-5'
    echo 'rr_phi_max_minimum = 0.0'
    echo "rr_phi_max_maximum = ${r_max}"
  } >> "$parameter_file"
}

write_seeded_params() {
  local parameter_file="$1"
  local source_dir="$2"
  local ell="$3"
  local n="$4"
  local r_max="$5"
  local mode="$6"
  local value="$7"
  local potential="${8:-free}"
  local coupling_name="${9:-none}"
  local coupling_value="${10:-0.0}"
  local source_n source_dr source_omega dr read_mode
  source_n=$(metadata_value "$source_dir" NrInterior)
  source_dr=$(metadata_value "$source_dir" dr)
  source_omega=$(metadata_value "$source_dir" omega)
  dr=$(numeric_helper divide "$r_max" "$n")
  read_mode=1
  if [ "$source_n" != "$n" ] || ! numeric_helper close "$source_dr" "$dr" 1.0e-14; then
    read_mode=3
  fi
  mkdir -p "$(dirname "$parameter_file")"
  {
    echo "dr = ${dr}"
    echo "dz = ${dr}"
    echo "NrInterior = ${n}"
    echo "NzInterior = ${n}"
    echo 'order = 4'
    echo "readInitialData = ${read_mode}"
    echo "log_alpha_i = \"${source_dir}/log_alpha_f.asc\""
    echo "beta_i = \"${source_dir}/beta_f.asc\""
    echo "log_h_i = \"${source_dir}/log_h_f.asc\""
    echo "log_a_i = \"${source_dir}/log_a_f.asc\""
    echo "psi_i = \"${source_dir}/psi_f.asc\""
    echo "lambda_i = \"${source_dir}/lambda_f.asc\""
    echo "w_i = \"${source_dir}/w_f.asc\""
    if [ "$read_mode" = "3" ]; then
      echo "NrTotalInitial = $((source_n + 4))"
      echo "NzTotalInitial = $((source_n + 4))"
      echo 'order_i = 4'
      echo 'ghost_i = 2'
      echo "dr_i = ${source_dr}"
      echo "dz_i = ${source_dr}"
    fi
    echo 'scale_u0 = 1.0'
    echo 'scale_u1 = 1.0'
    echo 'scale_u2 = 1.0'
    echo 'scale_u3 = 1.0'
    if [ "$mode" = "amplitude" ]; then
      echo "scale_u4 = ${value}"
      echo 'scale_u6 = 1.0'
      echo 'fixedPhi = 1'
      echo 'fixedPhiR = 2'
      echo 'fixedPhiZ = 2'
      echo 'fixedOmega = 0'
    elif [ "$mode" = "omega" ]; then
      echo 'scale_u4 = 1.0'
      printf 'scale_u6 = %s\n' "$(numeric_helper scale "$value" "$source_omega")"
      echo 'fixedPhi = 0'
      echo 'fixedOmega = 1'
    else
      echo "ERROR: unknown seeded solve mode $mode" >&2
      return 2
    fi
    echo 'scale_u5 = 1.0'
    echo "l = ${ell}"
    echo 'm = 1.0'
    echo "potential = \"${potential}\""
    if [ "$coupling_name" != "none" ]; then
      echo "${coupling_name} = ${coupling_value}"
    fi
    echo 'sweep = 0'
    echo 'scale_next = 1.0'
    echo 'hwl_max = 100000'
    echo 'hwl_min = 1'
    echo 'w_min = 0.0'
    echo 'w_max = 1.0'
    echo 'solverType = 1'
    echo 'localSolver = 1'
    echo 'epsilon = 1.0E-10'
    echo 'maxNewtonIter = 50'
    echo 'lambda0 = 1.0E-3'
    echo 'lambdaMin = 1.0E-6'
    echo 'useLowRank = 0'
    echo 'max_initial_guess_checks = 8'
    echo 'norm_f0_target = 1.0E-5'
    echo 'rr_phi_max_minimum = 0.0'
    echo "rr_phi_max_maximum = ${r_max}"
    echo 'alphaBoundOrder = 1'
    echo 'betaBoundOrder = 1'
    echo 'hBoundOrder = 1'
    echo 'aBoundOrder = 1'
    echo 'phiBoundOrder = 1'
  } > "$parameter_file"
}

run_validation_attempt() {
  local parameter_file="$1"
  local attempt_root="$2"
  local target_id="${3:-}"
  local output_dir exit_code
  mkdir -p "$attempt_root"
  set +e
  (
    cd "$attempt_root"
    "$ROTBOSON_DIR/ROTBOSON" "$parameter_file"
  )
  exit_code=$?
  set -e
  output_dir=$(find "$attempt_root" -mindepth 1 -maxdepth 1 -type d -name 'pot=*,l=*,w=*' -print | sort | tail -n 1)
  [ "$exit_code" -eq 0 ] || return 1
  [ -n "$output_dir" ] || return 1
  if [ -n "$target_id" ]; then
    validation_python check-solution --path "$output_dir" --target-id "$target_id" >/dev/null || return 1
  else
    validation_python check-solution --path "$output_dir" >/dev/null || return 1
  fi
  VALIDATION_SOLUTION=$output_dir
}

initialize_branch_index() {
  local index="$1"
  if [ ! -f "$index" ]; then
    mkdir -p "$(dirname "$index")"
    printf 'step\tpath\tomega\tmass\tphi_max\tamplitude_increment\n' > "$index"
  fi
}

append_branch_point() {
  local index="$1"
  local solution="$2"
  local increment="$3"
  local step omega mass phi temporary
  step=$(numeric_helper line-count-minus-one "$index")
  omega=$(metadata_value "$solution" omega)
  mass=$(metadata_value "$solution" M_Komar)
  phi=$(first_numeric_value "$solution/phi_max.asc")
  temporary="${index}.tmp.$$"
  cp "$index" "$temporary"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$step" "$solution" "$omega" "$mass" "$phi" "$increment" >> "$temporary"
  mv "$temporary" "$index"
}

latest_branch_solution() {
  local index="$1"
  tail -n 1 "$index" | cut -f2
}

run_branch_phase() {
  local phase="$1"
  local ell="${2:-1}"
  local branch_root="$VALIDATION_ROOT/l${ell}"
  local state_dir="$branch_root/state/branch"
  local index="$state_dir/index.tsv"
  local increment_file="$state_dir/increment.txt"
  local max_steps increment source parameter attempt factor retry step
  local profile_n profile_r profile_omega profile_psi initial_increment minimum_increment
  IFS=$'\t' read -r profile_n profile_r profile_omega profile_psi initial_increment minimum_increment \
    < <(validation_python profile --ell "$ell")
  mkdir -p "$state_dir" "$branch_root/params/branch" "$branch_root/work/branch"
  initialize_branch_index "$index"
  if [ "$(numeric_helper line-count "$index")" -eq 1 ]; then
    parameter="$branch_root/params/branch/seed.par"
    write_analytic_seed_params "$parameter" "$ell" "$profile_n" "$profile_r" "$profile_omega" "$profile_psi"
    attempt="$branch_root/work/branch/step_0000_seed"
    echo "Creating the rotating l=$ell free-field seed"
    run_validation_attempt "$parameter" "$attempt"
    append_branch_point "$index" "$VALIDATION_SOLUTION" 0.0
  fi
  if validation_python branch-ready --index "$index" --phase "$phase" --ell "$ell" >/dev/null 2>&1; then
    echo "$phase branch stage is already complete"
    return 0
  fi
  increment=$(cat "$increment_file" 2>/dev/null || echo "$initial_increment")
  max_steps="${VALIDATION_MAX_STEPS:-200}"
  for ((step=0; step<max_steps; step++)); do
    source=$(latest_branch_solution "$index")
    validation_python check-solution --path "$source" >/dev/null
    retry=0
    while :; do
      factor=$(numeric_helper one-plus "$increment")
      parameter="$branch_root/params/branch/${phase}_step_$(printf '%04d' "$(numeric_helper line-count-minus-one "$index")")_try_${retry}.par"
      attempt="$branch_root/work/branch/${phase}_step_$(printf '%04d' "$(numeric_helper line-count-minus-one "$index")")_try_${retry}"
      write_seeded_params "$parameter" "$source" "$ell" "$profile_n" "$profile_r" amplitude "$factor"
      echo "Continuation phase=$phase source=$source amplitude_increment=$increment retry=$retry"
      if run_validation_attempt "$parameter" "$attempt"; then
        append_branch_point "$index" "$VALIDATION_SOLUTION" "$increment"
        increment=$(numeric_helper grow "$increment" "$initial_increment")
        write_validation_pointer "$increment_file" "$increment"
        break
      fi
      increment=$(numeric_helper half "$increment")
      retry=$((retry + 1))
      if ! numeric_helper ge "$increment" "$minimum_increment"; then
        echo "ERROR: continuation failed below minimum amplitude increment $minimum_increment" >&2
        return 1
      fi
    done
    if validation_python branch-ready --index "$index" --phase "$phase" --ell "$ell" >/dev/null 2>&1; then
      touch "$state_dir/${phase}.complete"
      echo "$phase branch stage completed"
      return 0
    fi
  done
  echo "ERROR: $phase stage reached VALIDATION_MAX_STEPS=$max_steps; resubmit to resume" >&2
  return 75
}

run_exact_target() {
  local ell="$1" target_id="$2" omega="$3" branch="$4" n="$5" r_max="$6"
  local potential="${7:-free}" coupling_name="${8:-none}" coupling_value="${9:-0.0}"
  local seed_root="${10:-}"
  local root="$VALIDATION_ROOT/l${ell}" index="$VALIDATION_ROOT/l${ell}/state/branch/index.tsv"
  local pointer="$root/state/exact/${target_id}.path" source parameter attempt
  mkdir -p "$(dirname "$pointer")" "$root/params/exact" "$root/work/exact"
  if validation_pointer_is_valid "$pointer" "$target_id"; then
    echo "Reusing exact checkpoint $target_id"
    return 0
  fi
  if [ "$potential" = "free" ]; then
    source=$(validation_python select-seed --index "$index" --omega "$omega" --branch "$branch")
  else
    [ -n "$seed_root" ] || {
      echo "ERROR: interacting target $target_id requires a seed root" >&2
      return 2
    }
    source=$(validation_python select-output-seed --root "$seed_root" --target-id "$target_id")
  fi
  parameter="$root/params/exact/${target_id}.par"
  attempt="$root/work/exact/${target_id}"
  write_seeded_params "$parameter" "$source" "$ell" "$n" "$r_max" omega "$omega" \
    "$potential" "$coupling_name" "$coupling_value"
  run_validation_attempt "$parameter" "$attempt" "$target_id"
  write_validation_pointer "$pointer" "$VALIDATION_SOLUTION"
  echo "Accepted exact solution $target_id: $VALIDATION_SOLUTION"
}

run_convergence_target() {
  local ell="$1" target_id="$2" grid_id="$3" n="$4" r_max="$5" omega="$6"
  local potential="${7:-free}" coupling_name="${8:-none}" coupling_value="${9:-0.0}"
  local root="$VALIDATION_ROOT/l${ell}"
  local source_pointer="$root/state/exact/${target_id}.path"
  local pointer="$root/state/convergence/${target_id}/${grid_id}.path"
  local source parameter attempt
  mkdir -p "$(dirname "$pointer")" "$root/params/convergence/$target_id" "$root/work/convergence/$target_id"
  validation_pointer_is_valid "$source_pointer" "$target_id" || {
    echo "ERROR: missing exact production checkpoint for $target_id" >&2
    return 1
  }
  if validation_pointer_is_valid "$pointer" "$target_id"; then
    echo "Reusing convergence checkpoint $target_id/$grid_id"
    return 0
  fi
  source=$(validation_solution_from_pointer "$source_pointer")
  parameter="$root/params/convergence/$target_id/${grid_id}.par"
  attempt="$root/work/convergence/$target_id/${grid_id}"
  write_seeded_params "$parameter" "$source" "$ell" "$n" "$r_max" omega "$omega" \
    "$potential" "$coupling_name" "$coupling_value"
  run_validation_attempt "$parameter" "$attempt" "$target_id"
  write_validation_pointer "$pointer" "$VALIDATION_SOLUTION"
  echo "Accepted convergence solution $target_id/$grid_id: $VALIDATION_SOLUTION"
}
