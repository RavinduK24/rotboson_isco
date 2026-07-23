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

## 2. One-Potential-At-A-Time Scans

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
