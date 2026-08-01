# ROTBOSON

ROTBOSON solves the stationary Einstein-Klein-Gordon equations for rotating boson stars in quasi-isotropic cylindrical coordinates. This workspace version adds five self-interaction models, self-describing output, and regression targets for the potential and Jacobian implementations.

## Repository Provenance

This repository is packaged for pure rotating boson-star ISCO studies. The base solver comes from `sontanon/ROTBOSON`, starting from upstream commit `f156eea` (`Add working instructions for l=1 data`). The current repository adds self-interaction potentials, metadata, ISCO postprocessing, regression tests, and HPC templates. See `UPSTREAM.md` for the provenance note.

The `sphboson/` directory is a separate modified copy of `sontanon/SPHBOSON` for spherical `l=0` boson stars. ROTBOSON itself is not changed to accept `l=0`; use `sphboson/` for non-rotating free/quartic/sextic runs and process its exported metric files with the same `scripts/rotboson_isco.py` extractor.

## HPC Clone

On the HPC login node:

```bash
git clone https://github.com/RavinduK24/rotboson_isco.git
cd rotboson_isco
sbatch hpc/run_build.slurm
```

For the matching spherical `l=0` solver:

```bash
cd sphboson
sbatch hpc/run_build.slurm
sbatch hpc/run_free.slurm
sbatch hpc/run_quartic.slurm
sbatch hpc/run_sextic.slurm
```

After the build succeeds, submit the potential-family scan scripts under `hpc/`, then run:

```bash
sbatch hpc/run_isco_scan.slurm
```

## Linux Build

The code requires GCC or ICC, Intel oneMKL/PARDISO, OpenMP, and libconfig. On a Linux system with oneMKL installed:

```bash
source /opt/intel/oneapi/setvars.sh
export LIBCONFIGROOT=/usr
make clean
make all compiler=gnu
```

The executable is `ROTBOSON`. The full Windows host build is not supported by the upstream Makefile.

## Scalar Potentials

The matter convention is

```text
L_Phi = -nabla(Phi*) . nabla(Phi) - V(x),   x = |Phi|^2.
```

Select a model with a string in the parameter file:

```text
potential = "free"       # V = m^2 x
potential = "quartic"    # V = m^2 x + lambda_4 x^2 / 2
potential = "sextic"     # V = m^2 x + lambda_6 x^3 / 3
potential = "axion"      # V = m^2 f_axion^2 [1-cos(sqrt(2x)/f_axion)]
potential = "solitonic"  # V = m^2 x (1-2x/sigma_soliton^2)^2
potential = "kkls"       # normalized KKLS polynomial
```

Numeric `potential_type = 0` through `5` remains supported. The active parameters are `lambda_4`, `lambda_6`, `f_axion`, `sigma_soliton`, and `kappa_kkls`. Runnable low-resolution files are in `examples/`.

All models satisfy `V_x(0)=m^2`, so the asymptotic scalar decay remains `sqrt(m^2-omega^2)`. The implementation centralizes `V`, `V_x`, and `V_xx` in `src/potential.c`; stress-energy equations use `V`, while the Klein-Gordon equation and its scalar Jacobian use `V_x` and `V_xx`.

## Run And Continue

From the output directory:

```bash
../ROTBOSON ../examples/free.par
../ROTBOSON ../examples/quartic.par
```

For continuation, point the existing `log_alpha_i`, `beta_i`, `log_h_i`, `log_a_i`, `psi_i`, `lambda_i`, and `w_i` settings at a converged directory, then use the existing `scale_next` and `sweep` controls. Do not seed across different potential conventions or coupling values without first checking that the starting solution is in the intended weak-coupling regime.

Output directories begin with the model and active coupling, then contain `l`, final `w`, `dr`, and `N`. Repeated runs receive a `run=NNN` suffix. Every solution contains `run_metadata.txt` with the model, all couplings, grid, final frequency, convergence status, and global diagnostics. Metadata-free upstream directories remain valid legacy free-field inputs to the Python tools.

## Verification

In the configured Linux oneMKL/libconfig environment:

```bash
make test-potential
make test-jacobian
```

`test-potential` checks analytic first and second derivatives and weak-field limits. `test-jacobian` compares `J v` with a centered directional finite difference for orders 2 and 4 and all six potential types; the fourth-order grid exercises the `cc`, `cs`, `sc`, and `ss` CSR paths.

## ISCO Processing

Run the standalone processor from this ROTBOSON directory after one or more solution sequences finish:

```bash
python scripts/rotboson_isco.py out \
  --output-dir results/rotboson_isco \
  --export-profiles
```

To add physical columns for a scalar mass of `1e-11 eV`:

```bash
python scripts/rotboson_isco.py out \
  --output-dir results/rotboson_isco_1e-11eV \
  --boson-mass-ev 1e-11 --strict
```

The processor analyzes both orbital branches, records every radial marginal-stability crossing, and reports the first boundary encountered moving inward from the outer stable region as the disk-facing ISCO. Stable horizonless solutions with no such boundary are reported as `all_stable_no_isco`; no radius is invented.

Primary outputs are `isco_summary.csv`, `marginal_orbits.csv`, `scan_diagnostics.csv`, optional `profiles/*.csv`, and comparison plots. `isco_summary.csv` includes explicit `isco_std_*`, `isco_theo_*`, `stability_topology`, and `classification_message` columns; the definition rules are logged in `ISCO definitions.md`. The full workflow is documented in `docs/rotboson_workflow.md`, and the change ledger is `modifies rotboson.md`.
