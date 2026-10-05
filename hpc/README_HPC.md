# PolyU HPC ROTBOSON workflow

The scripts assume the checkout is:

```text
$HOME/ROTBOSON_ISCO/ROTBOSON
```

## Phase 1-2 literature validation

Preview the free-field jobs, dependencies, arrays, resources, targets, and
output locations without contacting SLURM:

```bash
cd $HOME/ROTBOSON_ISCO/ROTBOSON
bash hpc/submit_free_validation.sh --ell 1 --dry-run
```

Submit the complete rotating validation with:

```bash
bash hpc/submit_free_validation.sh --ell 1
```

The helper submits this `afterok` chain:

1. build plus `make test-potential`, `make test-jacobian`, and Python tests;
2. weak/fundamental `l=1` continuation;
3. adaptive continuation through the frequency minimum until the rising third
   branch brackets `omega=0.9`;
4. a four-element exact-frequency array (`%2` concurrency);
5. a 16-element interpolation/re-solve array (`%2` concurrency);
6. CSV, JSON, and Markdown report generation.

Every task requests partition `h07q2`, 4 CPUs, 128 GB, and 72 hours. The four
exact solves provide the production-grid member of each five-grid matrix, so
the convergence array does not repeat them. The generated tree is:

```text
validation/results/
  logs/
  l1/
    params/          generated parameter files
    work/            isolated solver attempts, including rejected attempts
    state/           branch index and accepted checkpoint pointers
    reports/         validation_report.{csv,json,md}
```

No validation stage deletes or writes solution directories in `out/`. A rerun
checks each pointer and reuses only converged, nonvacuum solutions with the
right target identity. Failed continuation steps halve the scalar-amplitude
increment down to `0.001`. If a 72-hour allocation or the per-invocation step
guard is reached, run the same submission command again; completed stages are
cheap validation checks and the incomplete stage continues from its last
accepted branch point. Set `VALIDATION_MAX_STEPS` only when debugging.

The optional spherical sequence is deliberately separate and explicit:

```bash
bash hpc/submit_free_validation.sh --ell 0 --dry-run
bash hpc/submit_free_validation.sh --ell 0
```

This routes to the bundled SPHBOSON solver and writes beneath
`validation/results/l0/`; no `l=0` job is included in `--ell 1`. The manifest is
`validation/benchmarks.json`, while conventions, branch definitions, coupling
conversion, and literature provenance are fixed in
`docs/literature_validation.md`.

The driver is data-driven for future rotating harmonics. Once literature
targets, grids, and a continuation profile for a new `ell` are added to the
manifest, the same `--ell INTEGER` interface derives its target and grid-array
sizes automatically.

Useful monitoring commands are:

```bash
squeue -u $USER
sacct -j JOBID --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS
tail -f validation/results/logs/third_branch_JOBID.out
```

The report job exits nonzero when an acceptance rule fails. That is a numerical
validation result, not a report-generation failure; inspect the Markdown
report for explicit reasons.

## Rotating quartic validation

The interacting driver submits only `l=1` and automatically chains the existing
production continuation into the literature checks:

```bash
cd $HOME/ROTBOSON_ISCO/ROTBOSON
bash hpc/submit_interacting_validation.sh --ell 1 --dry-run
bash hpc/submit_interacting_validation.sh --ell 1
```

The dependency chain is:

1. build and regression tests;
2. free weak seed and branch for `l=1`;
3. fixed-field quartic homotopy through `Lambda=1..100`;
4. homotopy through `Lambda=120..200`;
5. the `Lambda=200` amplitude branch through an internal mass maximum;
6. an exact solve at the rounded literature frequency `omega=0.82`;
7. four additional resolution/domain solves;
8. equilibrium, coupling-homotopy, and sequence-maximum reports.

The solver convention is `lambda_4=4*pi*Lambda`, so `Lambda=200` becomes
`lambda_4=2513.2741228718345`. The exact/grid work is isolated under:

```text
validation/results/interacting/quartic_Lambda_200/l1/
  params/
  work/
  state/
  reports/
```

The report directory contains three report families in CSV/JSON/Markdown:

- `validation_report`: the exact `omega=0.82` five-grid matrix;
- `coupling_validation_report`: every `Lambda=1..200` homotopy checkpoint;
- `sequence_peak_validation_report`: the sampled `Mmax` and its frequency.

The last two read the established production checkpoints beneath `out/`.
Intermediate couplings are tested for solver, coupling, physical consistency,
and continuation continuity; they are not labeled as precise literature
observables. The quantitative literature comparison is the rounded Table II
target `Mmax=3.48`, `omega=0.82` at `l=1`, `Lambda=200`.

This workflow is limited to rotating `l=k=1,2,3,4` free-field models and the
Grandclement et al. (2014) quartic benchmark at paper coupling `Lambda=200`.
ROTBOSON uses `lambda_4=4*pi*Lambda`, so the benchmark coupling is:

```text
lambda_4 = 2513.2741228718345
```

## Pull, build, and dry test

```bash
cd $HOME/ROTBOSON_ISCO/ROTBOSON
git pull --ff-only origin main
sbatch hpc/run_build.slurm
sbatch hpc/run_dry_test.slurm
```

The build job runs both the potential test and the directional Jacobian test.
The latter includes quartic checks for `l=1,2,3,4` at
`lambda_4=100,500,1000,2513.2741228718345`.

## Production jobs

Submit these four production stages in order, waiting for each array to finish
successfully before submitting the next:

```bash
sbatch hpc/run_free.slurm
sbatch hpc/run_quartic_homotopy_low.slurm
sbatch hpc/run_quartic_homotopy_high.slurm
sbatch hpc/run_quartic.slurm
```

Every production file is a `1-4%2` SLURM array. The array index is `l`, at most
two tasks run concurrently, and each task has a 72-hour limit. To establish the
`l=1` benchmark first, submit any stage with `--array=1` and submit `2-4%2`
later.

The stages are:

1. `run_free.slurm`: independent free weak seed and amplitude branch for each
   `l`.
2. `run_quartic_homotopy_low.slurm`: carry the same weak star from `Lambda=0`
   through `Lambda=1,2,5,10,20,40,60,80,100`.
3. `run_quartic_homotopy_high.slurm`: continue through
   `Lambda=120,140,160,180,200`.
4. `run_quartic.slurm`: start from the weak `Lambda=200` checkpoint and create
   the mass-frequency branch with a small amplitude step.

During coupling homotopy, `fixedPhi=1`, `fixedOmega=0`, `scale_u4=1`, and
`sweep=0`. Thus only the coupling changes between consecutive solves. Each
accepted step must be converged, non-vacuum, and must not collapse in mass or
field amplitude relative to the previous checkpoint.

The low homotopy stage removes old quartic output for its own `l` only on its
first run. Completed coupling steps are checkpointed under:

```text
out/hpc_quartic_homotopy/checkpoints/l<l>/
```

If a task reaches the 72-hour limit, submit that same stage again. It reuses
valid checkpoints and restarts at the first incomplete coupling. To deliberately
discard its quartic checkpoints and outputs, submit the low stage with:

```bash
sbatch --export=ALL,RESET_HOMOTOPY=1 hpc/run_quartic_homotopy_low.slurm
```

The free and final quartic amplitude arrays also resume after a timeout. They
restart from the converged model with the lowest frequency and are marked
complete only after the sampled branch has a mass maximum with converged points
on both sides. Reset them deliberately with:

```bash
sbatch --export=ALL,RESET_FREE=1 hpc/run_free.slurm
sbatch --export=ALL,RESET_BRANCH=1 hpc/run_quartic.slurm
```

## Seed and grid settings

The code solves for regularized `psi`, while the physical field behaves as
`phi=rho^l*psi`. The analytic seeds therefore use `l`-dependent `psi0` values:

| `l` | `psi0` | `N` | `dr=dz` | outer radius | amplitude step |
|---:|---:|---:|---:|---:|---:|
| 1 | `1.000e-2` | 256 | `0.0625` | 16 | `1.03` |
| 2 | `2.060e-3` | 256 | `0.0625` | 16 | `1.025` |
| 3 | `3.270e-4` | 256 | `0.125` | 32 | `1.02` |
| 4 | `4.380e-5` | 256 | `0.125` | 32 | `1.015` |

These are branch-finding grids. Important configurations still require domain
and resolution convergence checks before publication use.

Production solves use `epsilon=1e-10`, `maxNewtonIter=50`,
`lambda0=1e-3`, and `lambdaMin=1e-6`.

## Monitoring

```bash
squeue -u $USER
sacct -j JOBID --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS
tail -f rotboson_free_JOBID_TASKID.out
tail -f rotboson_qhom_low_JOBID_TASKID.out
tail -f rotboson_qhom_high_JOBID_TASKID.out
tail -f rotboson_q200_JOBID_TASKID.out
```

Array log cleanup preserves every task belonging to the currently running
array. Old logs from earlier arrays with the same prefix are removed.

## Comparison targets

Grandclement et al. Table II gives:

| `l=k` | paper `Mmax` | paper `omega` at `Mmax` |
|---:|---:|---:|
| 1 | 3.48 | 0.82 |
| 2 | 4.08 | 0.80 |
| 3 | 4.81 | 0.78 |
| 4 | 5.59 | 0.76 |

Generate the local summary with:

```bash
python3 scripts/plot_rotboson_outputs.py --out-dir out --plot-dir results/hpc_scans
```

The CSV includes `eta_SI=lambda_4*phi_max^2/m^2` in addition to mass,
frequency, virial, field, and convergence diagnostics.
