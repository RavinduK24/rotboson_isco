# PolyU HPC SLURM Templates

These files assume the uploaded ROTBOSON directory is:

```text
$HOME/ROTBOSON_ISCO/ROTBOSON
```

Edit `ROTBOSON_DIR` in the scripts if your upload path is different.

## 1. Build

```bash
cd $HOME/ROTBOSON_ISCO/ROTBOSON
sbatch hpc/run_build.slurm
```

Check the build log. The executable should be:

```text
$HOME/ROTBOSON_ISCO/ROTBOSON/ROTBOSON
```

## 2. One-Potential-At-A-Time Production Sequences

The Student HPC queues have small concurrent-job limits, so these templates run one potential family per submitted job. Submit the next job only after the previous one finishes.

```bash
cd $HOME/ROTBOSON_ISCO/ROTBOSON
sbatch hpc/run_free.slurm
sbatch hpc/run_quartic.slurm
sbatch hpc/run_sextic.slurm
sbatch hpc/run_axion.slurm
sbatch hpc/run_solitonic.slurm
sbatch hpc/run_kkls.slurm
```

For matching non-rotating `l=0` free/quartic/sextic scans:

```bash
sbatch hpc/run_free_l0.slurm
sbatch hpc/run_quartic_l0.slurm
sbatch hpc/run_sextic_l0.slurm
```

Recommended initial order:

```text
run_free.slurm
run_quartic.slurm
run_sextic.slurm
run_axion.slurm
run_solitonic.slurm
run_kkls.slurm
```

The coupling values are defined near the top of each potential-specific file in `COUPLING_VALUES=(...)`. Generated parameter files are written to:

```text
out/hpc_<potential>_<coupling>_scan/params/
```

Each solver job now runs a production `l=1` sequence for every requested model:

```text
1. N=256, dr=dz=0.0625, fourth-order seed at omega=0.95
2. continuation from that seed using scale_next=1.1
3. repeated solutions until the ROTBOSON sweep termination criteria are reached
```

The `_l0` jobs use the same grid, frequency seed, continuation settings, and coupling grids, but use `out/l0_from_scratch.par` and `out/l0_from_initial_data.par` and write `l=0` solution directories.

`hpc/run_free.slurm` runs the free-field seed plus continuation. The self-interaction scripts do the same for each coupling value in their `COUPLING_VALUES` table. These are intended as the first production-quality sequence jobs, not the older `N=64` smoke tests. Publication use still requires checking convergence diagnostics, ISCO status/topology, and selected grid-refinement reruns.

Before rerunning the same potential/coupling, archive or move the old matching production output folders under `out/`. The continuation parameter points at the canonical seed directory, so repeated identical runs should be kept separate rather than mixed in one output root.

SLURM stdout/stderr files are written in the directory where you submitted the job.

ROTBOSON solution directories are created under `out/`.

## 3. Generic ISCO Postprocessing

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
