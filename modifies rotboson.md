# ROTBOSON Modification Ledger

Date: 2026-07-17

This file records the rotating-boson-star potential and ISCO work performed in this workspace. The starting tree already contained an incomplete free/quartic/sextic/axion patch; the entries below include corrections made to that inherited work.

## Matter Convention And Potential Equations

The code now uses `x = |Phi|^2` and `L_Phi = -nabla(Phi*) . nabla(Phi) - V(x)` consistently.

- Free: `V = m^2 x`, `V_x = m^2`, `V_xx = 0`.
- Quartic: `V = m^2 x + lambda_4 x^2/2`, `V_x = m^2 + lambda_4 x`, `V_xx = lambda_4`.
- Sextic: `V = m^2 x + lambda_6 x^3/3`, `V_x = m^2 + lambda_6 x^2`, `V_xx = 2 lambda_6 x`.
- Axion: `V = m^2 f_axion^2 [1-cos(sqrt(2x)/f_axion)]`, `V_x = m^2 sin(q)/q`, and `V_xx = m^2[cos(q)-sin(q)/q]/(2x)`, where `q=sqrt(2x)/f_axion`.
- Solitonic: `V = m^2 x(1-2x/sigma_soliton^2)^2` with analytic first and second derivatives.
- KKLS: `V = m^2 x[1-16 pi x/(1.1 kappa_kkls)+64 pi^2 x^2/(1.1 kappa_kkls^2)]` with analytic first and second derivatives.

The axion implementation uses a cancellation-safe `sin(q/2)^2` form and small-`q` series. Its origin values are exactly finite, including `V_x(0)=m^2` and `V_xx(0)=-m^2/(3 f_axion^2)`. All six models therefore retain the existing asymptotic decay constant `sqrt(m^2-omega^2)`.

## Corrections To The Inherited Partial Patch

- Corrected the axion argument from the inherited `phi/f_axion` convention to `sqrt(2x)/f_axion`.
- Corrected the inherited axion weak-field derivative from `m^2/2` to `m^2`.
- Corrected the inherited axion second derivative's sign, factors, and origin limit.
- Replaced diagnostic uses of `x V_x` with `V` in the matter Komar mass and GRV2/GRV3 stress-energy terms.
- Completed the second-order lambda-row Jacobian by adding the exact nonlinear correction `V-m^2 x` to the generated free-field baseline. The four fourth-order parity variants already use direct `V`, `V_x`, and `V_xx` expressions and were extended to all models.
- Removed the potential evaluator's MKL dependency so its formulas can be compiled and tested independently.

## Changed C Files

- `external/ROTBOSON/src/potential.h`: added potential IDs 0 through 5 and the centralized evaluator/name/coupling/output-tag API.
- `external/ROTBOSON/src/potential.c`: implemented all six `V`, `V_x`, and `V_xx` branches, axion series, string mapping, active-coupling lookup, and directory tags.
- `external/ROTBOSON/src/param.h`: added `sigma_soliton` and `kappa_kkls`; changed inactive positive-scale defaults for axion/solitonic/KKLS parameters.
- `external/ROTBOSON/src/parser.c`: added `potential="..."`, retained `potential_type=0..5`, parsed all couplings, validated active parameter domains, and generated potential-aware initial directory names.
- `external/ROTBOSON/src/rhs_vars.c`: routed all six residual equations through the centralized potential evaluator. Metric and lambda stress terms use `V`; the Klein-Gordon residual uses `V_x`.
- `external/ROTBOSON/src/csr_vars.c`: routed all five CSR implementations through the centralized evaluator; scalar derivatives use `V_x+2xV_xx`; metric/scalar and lambda/scalar terms use `V_x`; stress terms use `V`; completed the second-order lambda diagonal corrections.
- `external/ROTBOSON/src/analysis.c`: corrected Komar, GRV2, and GRV3 potential terms to use `V` and left the angular-momentum integral unchanged.
- `external/ROTBOSON/src/main.c`: printed active potential data, created collision-resistant names, checked rename errors, and wrote final `run_metadata.txt` after analysis.
- `external/ROTBOSON/Makefile`: includes `src/potential.c` in the solver and adds `test-potential` and `test-jacobian` targets.

## Parameter And Output Interface

Preferred selector values are `free`, `quartic`, `sextic`, `axion`, `solitonic`, and `kkls`. Numeric values 0 through 5 remain compatible. Active-domain validation is `lambda_4 >= 0`, `lambda_6 >= 0`, `f_axion > 0`, `sigma_soliton > 0`, and `kappa_kkls > 0`.

Directories are named with `pot=<model>`, the active coupling where applicable, then `l`, `w`, `dr`, and `N`. Existing targets are not overwritten; `run=NNN` is appended when needed.

Each completed directory receives `run_metadata.txt` format version 1 with the potential, numeric type, active coupling name/value, all five parameters, `m`, `l`, final omega, Cartesian and spherical grid information, error code, convergence status, Komar mass/angular momentum, GRV2, and GRV3.

Added runnable low-resolution parameter files:

- `external/ROTBOSON/examples/free.par`
- `external/ROTBOSON/examples/quartic.par`
- `external/ROTBOSON/examples/sextic.par`
- `external/ROTBOSON/examples/axion.par`
- `external/ROTBOSON/examples/solitonic.par`
- `external/ROTBOSON/examples/kkls.par`

## Python Output And ISCO Files

- `external/ROTBOSON/scripts/plot_rotboson_outputs.py`: reads new metadata-prefixed names with legacy fallback, includes potential/coupling/convergence columns, groups plots by potential, and uses a headless plotting backend. Its default input is now `out/` so it works after uploading only `external/ROTBOSON`.
- `external/ROTBOSON/scripts/rotboson_isco.py`: standalone recursive scanner with one or more input roots, output directory, optional boson mass, optional radial profiles, strict mode, and plot controls.
- `external/ROTBOSON/tests/test_rotboson_isco.py`: analytic and interface regression suite.

The ISCO processor reconstructs on the equator:

```text
g_tt       = -alpha^2 + r^2 H^2 beta^2
g_tphi     = r^2 H^2 beta
g_phiphi   = r^2 H^2
g_rr       = A^2
```

Away from the equator it uses `rho^2=r^2 sin^2(theta)` and `g_thetatheta=A^2 r^2` for vertical stability. Radial metric derivatives use cubic splines. Circular frequencies are the two roots of the radial geodesic equation. The code then computes `E`, `L`, `u^t`, signed angular and positive cyclic frequency, ZAMO velocity, efficiency, and radial/vertical coordinate-time epicyclic frequencies from the fixed-`E,L` effective potential.

All radial epicyclic zeros are retained. The disk-facing ISCO is the outermost crossing reached first when moving inward from the resolved outer stable region. Explicit statuses are `found`, `all_stable_no_isco`, `no_timelike_orbit`, `unresolved_boundary`, `invalid_solution`, and `insufficient_resolution`.

Outputs are `isco_summary.csv`, `marginal_orbits.csv`, `scan_diagnostics.csv`, optional `profiles/*.csv`, and three comparison plots. km/Hz columns are absent unless `--boson-mass-ev` is supplied. Metadata-free directories are treated as legacy free-field runs.

## Added C Verification Files

- `external/ROTBOSON/tests/test_potential.c`: finite-difference checks for `V_x` and `V_xx`, origin checks, and weak-field/free limits for all potentials.
- `external/ROTBOSON/tests/test_jacobian_directional.c`: centered `Jv` checks for finite-difference orders 2 and 4 and potential types 0 through 5. The fourth-order test grid exercises center/center, center/symmetry, symmetry/center, and symmetry/symmetry CSR variants.

## Documentation Changes

- `external/ROTBOSON/README.md`: replaced the minimal upstream note with current build, potential, continuation, metadata, verification, ISCO, and physical-unit instructions.
- `external/ROTBOSON/docs/rotboson_workflow.md`: added potential-scan, continuation, standalone ISCO, multi-root, strict-validation, and physical-unit examples; noted the new free-field name prefix. Moved inside ROTBOSON so it is included in HPC uploads of this directory.
- `external/ROTBOSON/modifies rotboson.md`: this ledger, moved inside ROTBOSON for the same upload reason.

## Verification Executed On This Host

Passed:

```text
python -m py_compile scripts/rotboson_isco.py scripts/plot_rotboson_outputs.py tests/test_rotboson_isco.py
python -m unittest tests.test_rotboson_isco -v
```

Result: 7 tests passed. Covered Schwarzschild `R_ISCO=6M`, `M Omega=1/(6 sqrt(6))`, `E=sqrt(8/9)`, Schwarzschild angular momentum, both Kerr branches, Minkowski no-orbit data, multiple crossings, outermost-crossing selection, insufficient radial resolution, malformed metadata-only discovery, and optional physical columns.

The C potential test was compiled with Visual C++ 2019 Build Tools using `/W4 /O2` and executed successfully:

```text
test_potential.c
potential.c
Generating Code...
potential tests passed
```

Legacy compatibility and post-processing smoke checks passed:

- `solution_rows(out)` loaded 11 metadata-free free-field solutions when run from `external/ROTBOSON`.
- The standalone scanner processed the existing `l=1,w=9.50000E-01,dr=2.50000E-01,N=0064` spherical output and emitted both branches as `all_stable_no_isco` without inventing a radius.
- Headless plotting emitted `isco_radius_vs_frequency.png`, `isco_angular_frequency.png`, and `isco_efficiency.png` from representative found rows.

Python verification used NumPy 2.3.5, SciPy 1.18.0, and Matplotlib 3.11.0. SciPy and Matplotlib were installed into the bundled Codex Python runtime for these tests; the project already declares these runtime dependencies.

## Unavailable Verification And Remaining Limits

This Windows host has no configured Linux/WSL distribution, Intel oneMKL installation, or libconfig/MKL solver build environment. Therefore these checks were added but could not be executed here:

- Full `make all` compilation and link of ROTBOSON.
- `make test-jacobian` against the complete oneMKL/libconfig build.
- Roundoff comparison of free-field residuals, CSR values, masses, angular momentum, GRV2, and GRV3 against an untouched upstream executable.
- Weak-coupling converged solver smoke runs for quartic, sextic, axion, solitonic, and KKLS models.

Run the commands documented in `README.md` in the target Linux oneMKL/libconfig environment before using a large production scan. In particular, treat the C directional Jacobian test and free-field roundoff comparison as release gates.

## File Relocation For HPC Upload

On 2026-07-18, ROTBOSON-related helper files were moved under `external/ROTBOSON` so that uploading only that directory includes the solver, examples, Python postprocessors, tests, workflow documentation, and this ledger.

- Moved `scripts/rotboson_isco.py` to `external/ROTBOSON/scripts/rotboson_isco.py`.
- Moved `scripts/plot_rotboson_outputs.py` to `external/ROTBOSON/scripts/plot_rotboson_outputs.py`.
- Moved `docs/rotboson_workflow.md` to `external/ROTBOSON/docs/rotboson_workflow.md`.
- Moved `tests/test_rotboson_isco.py` to `external/ROTBOSON/tests/test_rotboson_isco.py`.
- Moved workspace-root `modifies rotboson.md` to `external/ROTBOSON/modifies rotboson.md`.
- Updated `external/ROTBOSON/README.md`, `external/ROTBOSON/docs/rotboson_workflow.md`, and `external/ROTBOSON/scripts/plot_rotboson_outputs.py` so commands and defaults are relative to the ROTBOSON directory.

Relocation verification from `external/ROTBOSON`:

```text
C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m py_compile scripts/rotboson_isco.py scripts/plot_rotboson_outputs.py tests/test_rotboson_isco.py
```

Result: passed.

```text
C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe -m unittest tests.test_rotboson_isco -v
```

Result: 7 tests passed.

## HPC SLURM Templates

Added PolyU-oriented SLURM templates under `external/ROTBOSON/hpc`:

- `external/ROTBOSON/hpc/README_HPC.md`: short build, scan, and ISCO postprocessing instructions for an upload located at `$HOME/ROTBOSON_ISCO/ROTBOSON`.
- `external/ROTBOSON/hpc/run_build.slurm`: builds the solver with `MKLROOT=$HOME/intel/mkl/2024.1`, `LIBCONFIGROOT=$HOME/local`, and runs the potential and directional Jacobian tests.
- `external/ROTBOSON/hpc/run_parameter_scan.slurm`: generic SLURM array template controlled by `SCAN_ROWS`, where each row is `potential coupling_name coupling_value base_parameter_file`. The default table covers the expected initial scan for free, quartic, sextic, axion, solitonic, and KKLS models.
- `external/ROTBOSON/hpc/run_isco_scan.slurm`: generic ISCO postprocessing template controlled by `RUN_ROOTS`, `RESULT_TAG`, and `EXTRA_ARGS`.
- Removed the quartic-specific `run_quartic_scan.slurm` and `run_isco_quartic.slurm` templates in favor of the generic files.
- Updated `run_build.slurm` and `run_parameter_scan.slurm` to use `${LD_LIBRARY_PATH:-}` so `set -u` does not fail on HPC nodes where `LD_LIBRARY_PATH` starts unset.
- Updated `ROTBOSON_DIR` defaults in all SLURM templates from `$HOME/ROTBOSON/ROTBOSON` to `$HOME/ROTBOSON_ISCO/ROTBOSON` for the planned fresh HPC upload layout.

On 2026-07-19, replaced the generic array/chunk scan template with one-potential-at-a-time SLURM files for the observed Student HPC limit behavior. The active 2026-08 HPC layout was later narrowed to the free-field and quartic jobs only.

- `external/ROTBOSON/hpc/run_free.slurm`: `l=1..4` free branches with `l`-dependent weak seeds.
- `external/ROTBOSON/hpc/run_quartic_homotopy_low.slurm`: fixed-field coupling continuation from the free seed through paper `Lambda=100`.
- `external/ROTBOSON/hpc/run_quartic_homotopy_high.slurm`: checkpointed continuation from paper `Lambda=100` to `Lambda=200`.
- `external/ROTBOSON/hpc/run_quartic.slurm`: mass-frequency branches at `lambda_4=4*pi*200=2513.2741228718345`.
- Each production script is a `1-4%2` array so at most two tasks run concurrently and each task remains within the 72-hour scheduler cap.
- Removed `external/ROTBOSON/hpc/run_parameter_scan.slurm`.
- Removed inactive axion, KKLS, sextic, and solitonic SLURM entry points from `hpc/` so the active job list matches the current comparison plan.

Also applied the two C fixes that were required during the first HPC build attempt:

- `external/ROTBOSON/src/analysis.c`: removed duplicate `V_val`, `dV_val`, `d2V_val` declaration in `ex_analysis`.
- `external/ROTBOSON/src/rhs_vars.c`: added `extern` declarations for potential selector and coupling globals used by `compute_potential`.
