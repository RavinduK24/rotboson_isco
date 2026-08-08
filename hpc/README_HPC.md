# PolyU HPC ROTBOSON workflow

The scripts assume the checkout is:

```text
$HOME/ROTBOSON_ISCO/ROTBOSON
```

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
