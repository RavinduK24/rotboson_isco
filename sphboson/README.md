# SPHBOSON self-interaction and ISCO workflow

This repository is a modified, standalone copy of
[sontanon/SPHBOSON](https://github.com/sontanon/SPHBOSON). It solves the
spherically symmetric (`l=0`) Einstein-Klein-Gordon system and remains separate
from ROTBOSON, which is used for rotating (`l>=1`) solutions.

The local extensions add the same potential conventions used by the
`RavinduK24/rotboson_isco` workflow, potential-aware output metadata, direct
metric export for its ISCO scanner, tests, and PolyU SLURM templates. See
[UPSTREAM.md](UPSTREAM.md) for provenance. No license has been added because the
upstream repository does not provide one.

## Supported potentials

With `x = |Phi|^2`, select a potential using `potential = "..."`:

- `free`: `V = m^2 x`
- `quartic`: `V = m^2 x + (lambda_4/2) x^2`
- `sextic`: `V = m^2 x + (lambda_6/3) x^3`
- `axion`: `V = 2 m^2 f_axion^2 sin^2(sqrt(2x)/(2 f_axion))`
- `solitonic`: `V = m^2 x (1 - 2x/sigma_soliton^2)^2`
- `kkls`: `V = m^2 x (1 - a x + b x^2)`, where
  `a = 16 pi/(1.1 kappa_kkls)` and
  `b = 64 pi^2/(1.1 kappa_kkls^2)`

The residual and analytic Newton Jacobian both use `V`, `dV/dx`, and
`d2V/dx2`. The `free` selection reduces exactly to the original field
equations.

## Build and test

The solver requires Linux, Intel oneMKL, libconfig, GCC, and Make. On PolyU HPC:

```bash
export SPHBOSON_DIR=$HOME/ROTBOSON_ISCO/ROTBOSON/sphboson
cd "$SPHBOSON_DIR"
sbatch hpc/run_build.slurm
```

The build job runs the potential derivative tests and validates the exported
ISCO grid schema. A direct interactive build is:

```bash
make clean
make all compiler=gnu
make test
```

## Production scans

The production template uses `l=0`, `m=1`, `w0=0.95`, `dr=0.0625`,
`NrInterior=256`, and fourth-order finite differences. The HPC wrappers run a
clean external amplitude scan: each parameter file fixes one `phi0`, forces the
upstream internal continuation to stop after that one solved model, and writes
metadata containing the solved `phi_max`.

```bash
sbatch hpc/run_free.slurm
sbatch hpc/run_quartic.slurm
sbatch hpc/run_sextic.slurm
```

Quartic and sextic jobs each scan coupling values
`0, 1e-3, 1e-2, 1e-1, 1, 10`. The default amplitude grid is
`phi0 = 0.005, 0.0075, 0.010, 0.015, 0.020, 0.030, 0.040, 0.060, 0.080, 0.100,
0.150, 0.200, 0.300, 0.400`. Override it at submission time with, for example:

```bash
PHI0_VALUES="0.01 0.02 0.04 0.08 0.16 0.32" sbatch hpc/run_free.slurm
```

Each submission creates a timestamped directory under `out/`; generated
solutions and logs are intentionally ignored by Git.

Each `phi0` run is isolated under `solutions/<label>/`. If a low-amplitude or
otherwise difficult point fails, the job records it in `run_status.tsv` and
continues to the next `phi0` value instead of aborting the whole scan.

## ISCO extraction

Every solution writes the six two-dimensional metric files and
`run_metadata.txt` expected by the current ROTBOSON ISCO scanner. The spherical
isotropic metric is exported with `beta=0` and
`log_h = log_a = 2 log_psi`. Radial ghost cells are excluded.

If the rotating and spherical repositories use the default HPC locations:

```bash
sbatch hpc/run_isco_scan.slurm
```

For one specific scan root:

```bash
INPUT_ROOT=$SPHBOSON_DIR/out/hpc_free_l0_YYYYMMDD_HHMMSS \
OUTPUT_DIR=$SPHBOSON_DIR/results/isco_free_l0 \
sbatch hpc/run_isco_scan.slurm
```

The static metric has no preferred rotation direction. The scanner therefore
reports two sign branches with the same circular-orbit radii, energies, and
stability, while their angular momenta have opposite signs. They are not
physically distinct co- and counter-rotating branches.

## Validation limits

Passing unit tests confirms potential derivatives, the free-field reduction,
and file-format compatibility. Production use still requires resolution and
outer-boundary convergence studies, comparison of ADM and Komar masses, and
comparison against published spherical boson-star sequences.
