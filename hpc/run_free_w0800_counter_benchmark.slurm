#!/bin/bash
# Exact free-field l=1, omega=0.8 equilibrium and counter-rotating orbit
# topology benchmark.  The equilibrium values are compared with the published
# M and J reference; the orbit topology is compared with Zhang et al. (2022).
#SBATCH --job-name=rotboson_w0800
#SBATCH --partition=h07q2
#SBATCH --cpus-per-task=4
#SBATCH --mem=128G
#SBATCH --time=72:00:00
#SBATCH --output=rotboson_w0800_%j.out
#SBATCH --error=rotboson_w0800_%j.err

set -euo pipefail
export MKLROOT=${MKLROOT:-$HOME/intel/mkl/2024.1}
export LIBCONFIGROOT=${LIBCONFIGROOT:-$HOME/local}
export LD_LIBRARY_PATH=$MKLROOT/lib:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib:${LD_LIBRARY_PATH:-}
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-4}

ROTBOSON_DIR=${ROTBOSON_DIR:-$HOME/ROTBOSON_ISCO/ROTBOSON}
PYTHON_BIN=${PYTHON_BIN:-/hpcapps/Anaconda3/Anaconda3-2023.03-1/bin/python3}
"$PYTHON_BIN" -c 'from __future__ import annotations; import numpy, scipy' >/dev/null

TARGET_OMEGA=0.8
N=512
RMAX=64
ROOT=$ROTBOSON_DIR/validation/results/free_w0800_counter_benchmark
STATE=$ROOT/state
PARAMS=$ROOT/params
WORK=$ROOT/work
REPORTS=$ROOT/reports
OUT=$ROTBOSON_DIR/out
mkdir -p "$STATE" "$PARAMS" "$WORK" "$REPORTS"

source "$ROTBOSON_DIR/hpc/validation_lib.sh"

nearest_retained_source() {
  "$PYTHON_BIN" - "$OUT/family_scan_Lambda_0/l1/work" "$TARGET_OMEGA" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
target = float(sys.argv[2])
required = ('log_alpha_f.asc', 'beta_f.asc', 'log_h_f.asc', 'log_a_f.asc',
            'psi_f.asc', 'lambda_f.asc', 'w_f.asc', 'run_metadata.txt')
best = None
for metadata in root.rglob('run_metadata.txt'):
    directory = metadata.parent
    if not all((directory / name).is_file() for name in required):
        continue
    values = {}
    for line in metadata.read_text().splitlines():
        key, sep, value = line.partition('=')
        if sep:
            values[key] = value
    if values.get('convergence_status') != 'converged' or values.get('potential') != 'free':
        continue
    omega = float(values['omega'])
    candidate = (abs(omega - target), directory)
    if best is None or candidate[0] < best[0]:
        best = candidate
if best is None:
    raise SystemExit('no retained converged free-field source profile found')
print(best[1])
PY
}

if [[ -s "$STATE/exact.path" && -d $(head -n 1 "$STATE/exact.path") ]]; then
  solution=$(head -n 1 "$STATE/exact.path")
  echo "Reusing exact omega=0.8 solution: $solution"
else
  source_dir=$(nearest_retained_source)
  source_dir=$(readlink -f -- "$source_dir")
  [[ -d "$source_dir" ]] || { echo "ERROR: source profile missing: $source_dir" >&2; exit 1; }
  echo "Seeding omega=0.8 from retained profile: $source_dir"
  parameter=$PARAMS/l1_free_w0800_R64_N512.par
  attempt=$WORK/exact
  write_seeded_params "$parameter" "$source_dir" 1 "$N" "$RMAX" omega "$TARGET_OMEGA" free none 0.0
  run_validation_attempt "$parameter" "$attempt"
  solution=$VALIDATION_SOLUTION
  printf '%s\n' "$solution" > "$STATE/exact.path"
  echo "Accepted exact omega=0.8 solution: $solution"
fi

RESULT_DIR=$REPORTS/isco
"$PYTHON_BIN" "$ROTBOSON_DIR/scripts/rotboson_isco.py" "$solution" \
  --output-dir "$RESULT_DIR" --export-profiles

"$PYTHON_BIN" - "$solution" "$RESULT_DIR/isco_summary.csv" "$REPORTS/benchmark_summary.md" <<'PY'
import csv
import math
import pathlib
import sys

solution, summary, output = map(pathlib.Path, sys.argv[1:])
meta = {}
for line in (solution / 'run_metadata.txt').read_text().splitlines():
    key, sep, value = line.partition('=')
    if sep:
        meta[key] = value

def last_number(name):
    rows = [line.split()[0] for line in (solution / name).read_text().splitlines()
            if line.strip() and not line.lstrip().startswith('#')]
    return float(rows[-1])

mass = float(meta['M_Komar'])
angular = float(meta['J_Komar'])
# The spherical output begins at the origin; -g_tt(0)=alpha(0)^2.
for line in (solution / 'sph_log_alpha_f.asc').read_text().splitlines():
    if line.strip() and not line.lstrip().startswith('#'):
        lapse = math.exp(2.0 * float(line.split()[0]))
        break
else:
    raise RuntimeError('missing spherical lapse data')
targets = {'mass': 1.307785917, 'angular': 1.371813099, 'lapse': 0.419928161}
with summary.open(newline='') as handle:
    rows = list(csv.DictReader(handle))
counter = next(row for row in rows if row['orbital_branch'] == 'counter')
with output.open('w') as handle:
    handle.write('# Free l=1, omega=0.8 counter-rotating benchmark\n\n')
    handle.write('## Equilibrium comparison\n\n')
    handle.write('| Observable | computed | literature | relative error |\n|---|---:|---:|---:|\n')
    for name, value in [('mass', mass), ('angular', angular), ('lapse', lapse)]:
        reference = targets[name]
        handle.write('| {} | {:.10g} | {:.10g} | {:.3e} |\n'.format(
            name, value, reference, abs(value-reference)/abs(reference)))
    handle.write('\n## Counter-rotating circular-orbit topology\n\n')
    handle.write('- status: `{}`\n'.format(counter['status']))
    handle.write('- topology: `{}`\n'.format(counter['stability_topology']))
    handle.write('- selected boundary: `{}`\n'.format(counter['isco_std_selection_kind']))
    handle.write('- selected circumferential radius: `{}`\n'.format(counter['isco_std_circumferential_radius_over_M']))
    handle.write('\nZhang et al. (2022) classify the k=1, omega=0.8 counter-rotating case as stable inner and outer circular-orbit regions separated by an unstable band.\n')
PY

echo "Benchmark complete: $REPORTS/benchmark_summary.md"
