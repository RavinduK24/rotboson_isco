# Free-field literature validation (Phases 1-2)

This document defines the conventions and acceptance contract used by
`validation/benchmarks.json` and the HPC workflow. These phases validate
equilibrium solutions only. Circular-orbit and ICO/ISCO reproduction starts in
Phase 3.

## Conventions

- Natural units are `G=c=hbar=mu=1`; the scalar mass is therefore `m=1` in
  parameter files.
- The complex scalar is `Phi=phi(r,theta) exp(i(ell*varphi-omega*t))`.
  ROTBOSON calls the azimuthal harmonic integer `l`. The default validation is
  `ell=l=1`. ROTBOSON does not solve `l=0`; the explicit `--ell 0` route uses
  the bundled SPHBOSON solver.
- The stationary axisymmetric metric is represented in quasi-isotropic
  coordinates. A radius read directly from the numerical grid is a coordinate
  radius. It must not be compared with an areal or circumferential radius
  without performing the appropriate metric conversion.
- `M_ADM.asc` is the radial ADM surface estimate. `M_Komar1.asc` is the
  geometric surface Komar mass and `M_Komar2.asc` is the matter-volume Komar
  mass. `J_Komar1.asc` is the geometric surface angular momentum and
  `J_Komar2.asc` is the matter-volume angular momentum. The reported solver
  values are the averages of the two Komar estimates.
- The Noether charge is recovered as `Q=J_Komar2/ell` for rotating solutions.
  The validation compares the independent surface estimate `J_Komar1` with
  `ell*Q`.
- At the coordinate origin the shift contribution vanishes, so the reported
  central diagnostic is `-g_tt(0)=exp(2*log(alpha(0)))`, evaluated from the
  first value of `sph_log_alpha_f.asc`.

## Branch naming

The **fundamental branch** begins at the vacuum limit `omega -> 1` and is
followed by increasing the fixed scalar-field amplitude while `omega`
decreases. A frequency minimum is accepted only after at least two descending
and two rising converged points. The rising segment immediately after that
minimum is called the **third branch**, matching the benchmark terminology in
Gervalle et al. A fixed-frequency solution is assigned a branch from its seed;
frequency alone is never sufficient. The third-branch `omega=0.9` solution must
also pass its mass and central-lapse identity window.

## Self-interaction conversion

For later quartic validation, Grandclement, Some and Gourgoulhon use

`V(x)=m^2*x*(1+2*pi*Lambda*x)`.

ROTBOSON uses `V(x)=m^2*x+lambda_4*x^2/2`, hence
`lambda_4=4*pi*m^2*Lambda`; with `m=1`, paper `Lambda=200` is
`lambda_4=2513.2741228718345`. Couplings must always be recorded in both paper
and code conventions.

## Benchmarks and provenance

The exact numerical targets, precision flags, grid matrix, and tolerances live
in the machine-readable manifest. A higher harmonic is enabled by adding its
benchmark rows and one continuation profile to that manifest; the runner and
SLURM arrays derive their sizes from those records. The principal sources are:

- S. Ontanon and M. Alcubierre, *Rotating Boson Stars Using Finite Differences
  and Global Newton Methods*, [arXiv:2103.13993](https://arxiv.org/abs/2103.13993).
- P. Grandclement, C. Some and E. Gourgoulhon, *Models of rotating boson stars
  and geodesics around them*, [arXiv:1405.4837](https://arxiv.org/abs/1405.4837).
- Z. Meliani et al., *Circular geodesics and thick tori around rotating boson
  stars*, [arXiv:1510.04191](https://arxiv.org/abs/1510.04191). Its
  `omega=0.9` values are rounded and are deliberately treated as
  precision-limited.
- R. Gervalle et al., *Boson Star Factory: Past, Present, and Future*,
  [arXiv:2609.24913](https://arxiv.org/abs/2609.24913). This is the source of
  the high-precision `omega=0.995`, `omega=0.8`, and third-branch `omega=0.9`
  targets.

## Reproducibility boundary

All generated files are rooted at `validation/results/` by default. The
workflow never searches, deletes, or rewrites ordinary `out/` solution
directories. Each accepted continuation step has a durable pointer in
`validation/results/l1/state`; rerunning a stage validates and reuses it.
