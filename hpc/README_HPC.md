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

The generated dry and production parameter files set `rr_phi_max_maximum=16.0`, matching the outer radius of the configured grids. Larger explicit values are rejected by the ROTBOSON parser.

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

`hpc/run_free.slurm` runs the free-field seed plus continuation. It is the `Lambda=0` free-field comparison.

`hpc/run_quartic.slurm` runs a direct code-parameter quartic scan:

```text
lambda_4 = 1e-3, 1e-2, 1e-1, 1, 10, 100, 1000,
           1256.6370614359173, 2513.2741228718345,
           1e4, 12566.370614359172
```

ROTBOSON's quartic potential is:

```text
V = m^2 x + lambda_4*x^2/2,  x=|Phi|^2
```

Grandclement et al. use:

```text
V = m^2 |Phi|^2 (1 + 2*pi*Lambda*|Phi|^2)
```

With `m=1`, the matching coefficient is therefore `lambda_4 = 4*pi*Lambda`. Two values in the direct `lambda_4` scan correspond to paper-convention reference points:

```text
Lambda=100  -> lambda_4=1256.6370614359173
Lambda=200  -> lambda_4=2513.2741228718345
Lambda=1000 -> lambda_4=12566.370614359172
```

The direct 2014 Table II comparison quoted for `Lambda=200` is included as `lambda_4=2513.2741228718345`.

These are intended as the first production-quality sequence jobs, not the older `N=64` smoke tests. Publication use still requires checking convergence diagnostics and selected grid-refinement reruns.

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
