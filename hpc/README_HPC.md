# PolyU HPC SLURM Templates

These files assume the uploaded ROTBOSON directory is:

```text
$HOME/ROTBOSON_ISCO/ROTBOSON
```

Edit `ROTBOSON_DIR` in the scripts if your upload path is different.

## 1. Pull

On the HPC login node, pull only fast-forward changes:

```bash
cd $HOME/ROTBOSON_ISCO/ROTBOSON
git pull --ff-only origin main
```

`--ff-only` is intentional: it refuses to merge if the HPC checkout has local commits or divergent history.

## 2. Four Manual Jobs

Submit these manually, in this order. Wait for each job to finish successfully before submitting the next one.

```bash
cd $HOME/ROTBOSON_ISCO/ROTBOSON
sbatch hpc/run_build.slurm
sbatch hpc/run_dry_test.slurm
sbatch hpc/run_free.slurm
sbatch hpc/run_quartic.slurm
```

The four jobs are:

```text
1. hpc/run_build.slurm
2. hpc/run_dry_test.slurm
3. hpc/run_free.slurm
4. hpc/run_quartic.slurm
```

The dry-test job runs low-resolution `N=64` free and quartic `lambda_4=1` smoke solves. If both complete, it removes the dry-test parameter files and dry-test solution directories. If it fails, the logs remain for debugging.

Each job removes older SLURM logs with its own prefix when it starts, while preserving the current job's active log:

```text
rotboson_build_*.out/.err
rotboson_dry_*.out/.err
rotboson_free_*.out/.err
rotboson_quartic_*.out/.err
```

Check the build log. The executable should be:

```text
$HOME/ROTBOSON_ISCO/ROTBOSON/ROTBOSON
```

## 3. Production Sequences

This comparison package is restricted to ROTBOSON rotating jobs for:

- free field
- quartic self-interaction

The full parameter list is in:

```text
hpc/rotboson_param_list.csv
```

Recommended initial order:

```text
run_free.slurm
run_quartic.slurm
```

Each script runs `k=l=1,2,3,4`. ROTBOSON is not used for `k=0` in this package; use only rotating comparisons unless you deliberately add a separate spherical solver run.

The coupling values are defined near the top of each potential-specific file in `COUPLING_VALUES=(...)`. Generated parameter files are written to:

```text
out/hpc_<potential>_<coupling>_scan/params/
```

Each solver job now runs production `k=l=1,2,3,4` sequences for every requested model:

```text
1. N=256, dr=dz=0.0625, fourth-order seed at omega=0.95
2. continuation from that seed using scale_next=1.1
3. repeated solutions until the ROTBOSON sweep termination criteria are reached
```

`hpc/run_free.slurm` runs the free-field seed plus continuation. `hpc/run_quartic.slurm` runs the earlier successful mild self-interaction scan:

```text
lambda_4 = 0, 1e-3, 1e-2, 1e-1, 1, 10
```

These are intended as the first production-quality sequence jobs, not the older `N=64` smoke tests. Publication use still requires checking convergence diagnostics and selected grid-refinement reruns.

This reverted scan is not the Grandclement et al. 2014 `Lambda=200` Table II run. In this code convention, the Grandclement quartic coefficient would be `lambda_4 = 4*pi*Lambda`, so `Lambda=200` would require `lambda_4=2513.2741228718345`. That high-coupling comparison is deliberately not submitted by the current `run_quartic.slurm`.

By default `CLEAN_OLD_DATA=1`, so every submitted production job deletes old matching solution folders under `out/` before rerunning. To keep existing data, submit with `CLEAN_OLD_DATA=0`.

SLURM stdout/stderr files are written in the directory where you submitted the job.

ROTBOSON solution directories are created under `out/`.

## 4. Generic ISCO Postprocessing

After the solver array finishes:

```bash
cd $HOME/ROTBOSON_ISCO/ROTBOSON
sbatch hpc/run_isco_scan.slurm
```

Edit these lines in `hpc/run_isco_scan.slurm` if needed:

```text
RUN_ROOTS=("out")
RESULT_TAG=isco_scan
EXTRA_ARGS=("--export-profiles" "--plots" "--strict")
```

ISCO tables and plots are written to `results/<RESULT_TAG>/`.

If the HPC Python environment lacks NumPy/SciPy/Matplotlib, create or load a Python environment before submitting this job, or edit the script's module section.
