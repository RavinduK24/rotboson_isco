# Rotating boson-star literature validation

This document defines the conventions and acceptance contract used by
`validation/benchmarks.json` and the HPC workflow. These phases validate
equilibrium solutions only. Circular-orbit and ICO/ISCO reproduction starts in
Phase 3.

## Conventions

The HPC build gate runs the directional Jacobian check for the fourth-order
stencil used by validation. The full `make test-jacobian` target also tests the
second-order stencil; its strong-quartic `ell=1` cases currently fail and are
tracked separately. Passing the production gate does not certify second-order
strong-coupling runs.

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
- `M_ADM.asc` is the finite-radius radial ADM surface estimate. Its endpoint is
  not the ADM mass at infinity and is retained for later radial extrapolation.
  `M_Schwarz.asc` supplies the asymptotic mass consistency check used during
  branch construction. `M_Komar1.asc` is the
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

For quartic validation, Grandclement, Some and Gourgoulhon use

`V(x)=m^2*x*(1+2*pi*Lambda*x)`.

ROTBOSON uses `V(x)=m^2*x+lambda_4*x^2/2`, hence
`lambda_4=4*pi*m^2*Lambda`; with `m=1`, paper `Lambda=200` is
`lambda_4=2513.2741228718345`. Couplings must always be recorded in both paper
and code conventions.

The interacting workflow records every fixed-field homotopy checkpoint at
paper couplings `Lambda=1,2,5,10,20,40,60,80,100,120,140,160,180,200` and
checks the potential tag, converted coupling, convergence, nonvacuum state,
Komar surface/volume consistency, and `J=ell*Q`. These intermediate points test
the numerical path through coupling space; they are not presented as
literature observable benchmarks.

At `ell=1`, `Lambda=200`, Table II gives the rounded sequence maximum
`Mmax=3.48` at `omega=0.82`. Validation therefore has two complementary tests:

1. locate the sampled internal maximum of the amplitude sequence and compare
   both its mass and frequency with the rounded table values;
2. solve exactly at `omega=0.82` and repeat that solution over the registered
   resolution and outer-boundary matrix.

Both comparisons use the manifest's precision-aware rounded tolerance. This
does not turn the two-decimal table entries into artificial high-precision
references.

## Benchmarks and provenance

### Numerical corrections and interacting grids

The interacting exact solution uses `R64_N512`. Resolution checks use
`N=256,384,512` at `R=64`; boundary checks use `R=48,64,80` at `dr=1/6`
(`N=288,384,480`). All interacting checkpoints must have a finite, positive
`r99 <= 0.8 R`. A failed containment check calls for a larger domain, not a
relaxed tolerance. Checkpoints on obsolete grids cannot satisfy the new grid.

Convergence compares successive numerical values of mass, angular momentum,
and central lapse, independently of rounded literature values. The final
relative change must be at most 0.001 and must not grow beyond a 1e-10
roundoff allowance. The report records both successive changes as uncertainty
indicators; these are not Richardson error bounds or proof of fourth-order
convergence. Every grid must converge and pass frequency, branch, grid, and
containment checks; strict benchmark tolerances gate the production solution.

The Simpson 3/8 coefficient and short-prefix handling have been corrected.
Old cumulative profiles and derived r99 values can change; existing equilibrium
fields remain usable as seeds, but final validation must use rebuilt code and
fresh solves. The scalar extension now matches a local boundary value to a
decaying bound-state tail instead of a constant. This is an initial guess,
which Newton must reconverge. Virial tail corrections now begin at the actual
last sampled polar radius; rectangular grids use the inscribed sphere.

Run `make test-numerics` after rebuilding. It checks polynomial quadrature on
both interval parities, short prefixes, and scalar-tail matching and decay.
The SLURM validation build includes this gate. ADM remains a finite-radius
profile: no extrapolation to infinity is claimed by these corrections.

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

The free-field workflow is wholly rooted at `validation/results/` and never
touches ordinary `out/` solutions. The interacting workflow deliberately
reuses the established production homotopy and `Lambda=200` amplitude branch
under `out/`, then writes its exact-frequency and grid re-solves beneath
`validation/results/interacting/quartic_Lambda_200/`. Reruns validate and reuse
both production checkpoints and isolated validation pointers.
