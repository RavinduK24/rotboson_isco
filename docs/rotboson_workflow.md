# ROTBOSON Reproduction Workflow

This note is for reproducing the upstream `sontanon/ROTBOSON` rotating boson-star runs, plotting the generated sequence, scanning self-interactions, and extracting ISCO data. It is kept inside the ROTBOSON directory so that uploading `external/ROTBOSON` to an HPC system includes the workflow.

## Current Local Status

- Work from the uploaded ROTBOSON directory itself.
- This Windows shell does not have `gcc` or `make` on `PATH`.
- WSL is installed, but no Linux distribution is installed.
- The upstream code requires Intel oneMKL/PARDISO and libconfig. These are not optional for the current Makefile.

Because of that, compile/run should be done in Linux or WSL Ubuntu.

## 1. Install A Linux Build Environment

On Windows, install Ubuntu for WSL:

```powershell
wsl --install Ubuntu
```

Restart if Windows asks. Then open Ubuntu and install basic tools:

```bash
sudo apt update
sudo apt install -y build-essential git wget pkg-config libconfig-dev python3 python3-pip
python3 -m pip install --user numpy matplotlib pandas
```

## 2. Install Intel oneMKL

Use Intel's current oneMKL installer, or the version used by the upstream README:

```bash
wget https://registrationcenter-download.intel.com/akdlm/IRC_NAS/2f3a5785-1c41-4f65-a2f9-ddf9e0db3ea0/l_onemkl_p_2024.1.0.695.sh
sudo sh ./l_onemkl_p_2024.1.0.695.sh
source /opt/intel/oneapi/setvars.sh
echo "$MKLROOT"
```

If the installer changes, use Intel's oneMKL Linux download page and keep the important result: `MKLROOT` must point to the MKL directory, usually something like `/opt/intel/oneapi/mkl/<version>`.

## 3. Enter The Workspace From WSL

Your Windows workspace will be mounted under `/mnt/d/...`:

```bash
cd "/mnt/d/PolyU docs/AP/Year 3 summer Numerical Relativity/external/ROTBOSON"
```

Set libconfig and MKL paths:

```bash
source /opt/intel/oneapi/setvars.sh
export LIBCONFIGROOT=/usr
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$MKLROOT/lib/intel64:$LIBCONFIGROOT/lib/x86_64-linux-gnu"
```

The upstream `env.bash` assumes libconfig is in `/usr/local`; Ubuntu's `libconfig-dev` package uses `/usr`, so set `LIBCONFIGROOT=/usr`.

## 4. Compile ROTBOSON

```bash
make clean
make all compiler=gnu
```

Expected result:

```text
Executable has been compiled.
```

and an executable:

```bash
ls -lh ROTBOSON
```

If compilation fails:

- `mkl.h: No such file`: `MKLROOT` is not set or oneMKL is not installed.
- `mkl_pardiso.h: No such file`: oneMKL include path is wrong.
- `libconfig.h: No such file`: install `libconfig-dev` and set `LIBCONFIGROOT=/usr`.
- linker cannot find `-lconfig`: check `/usr/lib/x86_64-linux-gnu/libconfig.so`.
- linker cannot find MKL libraries: check `$MKLROOT/lib/intel64`.

## 5. Run The Provided l=1 Seed

```bash
cd out
../ROTBOSON l1_from_scratch.par | tee l1_from_scratch.log
```

Expected legacy free-field output directory (new runs prepend `pot=free,`):

```text
l=1,w=9.50000E-01,dr=6.25000E-02,N=0256
```

Important files inside it:

- `w_f.asc`: final scalar frequency.
- `psi_f.asc`: final scalar field on the cylindrical grid.
- `log_alpha_f.asc`, `beta_f.asc`, `log_h_f.asc`, `log_a_f.asc`, `lambda_f.asc`: final metric/field variables.
- `M_ADM.asc`, `M_Komar1.asc`, `M_Komar2.asc`: mass diagnostics.
- `J_Komar1.asc`, `J_Komar2.asc`: angular momentum diagnostics.
- `GRV2.asc`, `GRV3.asc`: virial error diagnostics.
- `r99.asc`: radius containing 99 percent of the mass.

## 6. Run The Continuation Sequence

After the seed directory exists:

```bash
../ROTBOSON l1_from_initial_data.par | tee l1_from_initial_data.log
```

This repeatedly scales the previous scalar field by `scale_next = 1.1`, solves again, and continues until the field becomes too narrow or `w_min` is reached. The upstream README says the default run reaches roughly `omega = 0.675222` before stopping at this resolution.

## 7. Generate Summary And Plots

From the ROTBOSON directory:

```bash
cd "/mnt/d/PolyU docs/AP/Year 3 summer Numerical Relativity/external/ROTBOSON"
python3 scripts/plot_rotboson_outputs.py
```

Outputs:

```text
results/rotboson/rotboson_summary.csv
results/rotboson/mass_vs_omega.png
results/rotboson/angular_momentum_vs_omega.png
results/rotboson/particle_number_vs_omega.png
results/rotboson/r99_vs_omega.png
results/rotboson/angular_momentum_vs_mass.png
```

The script computes:

- `mass = 0.5 * (M_Komar1[-1] + M_Komar2[-1])`, matching the code's analysis convention.
- `J = 0.5 * (J_Komar1[-1] + J_Komar2[-1])`.
- `particle_number = J_Komar2[-1] / l`, matching the code comment that calls this baryon number.

## Self-Interaction Parameter Scans

Use one of the runnable files under `examples`, then vary only the active coupling and the continuation seed appropriate to that model:

```bash
cd out
../ROTBOSON ../examples/axion.par | tee axion_f1.log
../ROTBOSON ../examples/solitonic.par | tee solitonic_sigma1.log
../ROTBOSON ../examples/kkls.par | tee kkls_kappa10.log
```

The preferred string selectors are `free`, `quartic`, `sextic`, `axion`, `solitonic`, and `kkls`. Numeric `potential_type=0..5` is retained for old parameter generators. Check `run_metadata.txt` before accepting a run: `convergence_status` must be `converged`, and the potential/coupling must match the intended sequence.

The output name includes the potential and active coupling. A repeated identical run is given a `run=NNN` suffix, so parameter scans do not overwrite prior solutions.

## Standalone ISCO Scan

The orbit processor consumes only completed output files and does not import or call ROTBOSON:

```bash
cd "/mnt/d/PolyU docs/AP/Year 3 summer Numerical Relativity/external/ROTBOSON"
python3 scripts/rotboson_isco.py \
  out \
  --output-dir results/rotboson_isco \
  --export-profiles --strict
```

Multiple roots can be scanned together:

```bash
python3 scripts/rotboson_isco.py /data/free /data/quartic /data/axion \
  --output-dir /data/isco_comparison --plot-format pdf
```

Physical frequencies and radii are optional and are emitted only when a physical boson mass is supplied:

```bash
python3 scripts/rotboson_isco.py out \
  --output-dir results/rotboson_isco_physical \
  --boson-mass-ev 1.0e-11
```

Inspect all three tables:

- `isco_summary.csv`: one disk-facing result or explicit status per solution and branch.
- `marginal_orbits.csv`: every radial epicyclic zero, including additional inner crossings.
- `scan_diagnostics.csv`: grid sizes, valid-orbit counts, convergence state, and malformed-input messages.

The branch is classified relative to the sign of the star's Komar angular momentum. The scanner never substitutes a Kerr formula for the numerical metric and never assigns an ISCO when stable circular orbits continue to the center.

## 8. Compare With The Paper

If the paper provides tables, enter them into:

```text
data/rotboson_reference_l1.csv
```

with columns such as:

```csv
omega,mass,J,particle_number,r99
0.95,...
```

Then run:

```bash
python3 scripts/plot_rotboson_outputs.py --reference-csv data/rotboson_reference_l1.csv
```

If the paper only has figures, digitize the curves with WebPlotDigitizer:

1. Export the digitized curve as CSV.
2. Rename columns to match the script: `omega,mass,J,particle_number,r99`.
3. Re-run the plotting script with `--reference-csv`.

For a rigorous comparison table, compare relative differences:

```text
relative_error = abs(run_value - paper_value) / abs(paper_value)
```

Use the same model family: same `l`, same scalar mass `m`, same frequency normalization, same grid resolution if reported.

## 9. What To Report

For each reproduced sequence, report:

- Git commit or uploaded archive checksum of the ROTBOSON directory.
- Grid: `dr`, `dz`, `NrInterior`, `NzInterior`, finite difference `order`.
- Solver tolerance: `epsilon`, `maxNewtonIter`, `lambda0`, `lambdaMin`.
- Sequence range in `omega`.
- Maximum absolute and relative differences from the paper curves.
- Virial diagnostics `GRV2`, `GRV3`.
- Whether any solution has `ergoregion_flag = 1`.

## Static Boson-Star Build Plan

Do this after the rotating-code reproduction works, because it gives you a benchmark target.

### A. Start With Spherical Symmetry

Use a complex scalar field:

```text
Phi(t, r) = phi(r) exp(-i omega t)
```

and a static spherical metric:

```text
ds^2 = -alpha(r)^2 dt^2 + a(r)^2 dr^2 + r^2 dOmega^2
```

Unknowns:

- scalar amplitude `phi(r)`
- scalar derivative `psi(r) = dphi/dr`
- mass function `m(r)`, where `a(r)^2 = 1 / (1 - 2 m(r) / r)`
- lapse `alpha(r)`
- eigenfrequency `omega`

### B. Implement A Pure Boson-Star ODE Solver

Create `src/nseos/boson_static.py`.

Minimum functions:

- `boson_rhs(r, y, omega, mu, self_interaction)`
- `integrate_boson_star(phi_c, omega, r_max)`
- `shoot_frequency(phi_c)`
- `compute_mass_radius_profile(solution)`

Boundary conditions:

- at `r = 0`: `m(0) = 0`, `phi(0) = phi_c`, `psi(0) = 0`
- as `r -> infinity`: `phi(r) -> 0`, `alpha(r) -> 1`

The shooting target is exponential decay of `phi`; bad `omega` gives either divergence or sign-changing behavior.

### C. Validate The Pure Boson Solver

Generate a sequence over central amplitudes `phi_c`.

Plots:

- `M` vs `omega`
- `M` vs central scalar amplitude
- radius containing 99 percent of mass vs `M`
- scalar profiles `phi(r)` for selected models

Checks:

- `0 < omega / mu < 1` for bound states.
- `phi(r)` decays smoothly.
- no node for the ground state.
- ADM mass approaches known mini-boson-star scaling in dimensionless units.

### D. Then Add Static Fermion-Boson Coupling

Extend the ODE system with fluid pressure `P(r)` and your existing EOS interpolation:

```text
y = [m, alpha, phi, psi, P]
```

Matter sources become:

```text
T_total = T_fluid + T_scalar
```

Boundary conditions:

- fluid surface where `P = 0`
- scalar field continues outside the fluid and decays to zero
- total mass read at large outer radius

Inputs:

- central fluid pressure `P_c`
- central scalar amplitude `phi_c`
- scalar mass `mu`
- shooting frequency `omega`

Outputs:

- total ADM mass
- fermion mass contribution
- boson particle number
- fluid radius
- scalar effective radius
- compactness

### E. Only Then Move Toward Rotation

Once static pure boson and static mixed fermion-boson stars work:

1. Add slow rotation as a 1D frame-dragging equation.
2. Validate fluid-only slow rotation against RNS at low spin.
3. Use ROTBOSON outputs to validate pure rotating boson-star behavior.
4. Build the full 2D mixed rotating solver.

That order avoids mixing three hard problems at once: eigenvalue shooting, two-component matter, and axisymmetric elliptic equations.
