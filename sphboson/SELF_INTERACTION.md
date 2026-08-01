# Self-interaction implementation

SPHBOSON evolves a complex scalar with harmonic time dependence and radial
amplitude `phi(r)`. Define `x = phi^2` and let `V(x)` be the scalar potential.

The original free-field equations contain `m^2 phi^2` in the Einstein source
terms and `m^2 phi` in the Klein-Gordon equation. The generalized residual uses:

```text
lapse source:       V(x) - 2 omega^2 x / alpha^2
conformal source:   V(x) +   omega^2 x / alpha^2
scalar source:     (omega^2 / alpha^2 - dV/dx) phi
```

The analytic scalar-scalar Jacobian contains the derivative

```text
omega^2 / alpha^2 - dV/dx - 2 x d2V/dx2
```

These substitutions reproduce the original equations for
`V(x) = m^2 x`. Both centered and semi-one-sided fourth-order Jacobian stencils
use the same potential evaluation routine as the residual.

The change also corrects an upstream scalar diagonal Jacobian typo in both
stencils: the frequency term must contain `omega^2/alpha^2`, matching the
residual, rather than `omega^2/alpha`.

The outer scalar boundary condition remains the original free asymptotic decay,
because every supported potential has `dV/dx -> m^2` as `x -> 0`. Thus its
linear tail is still controlled by `sqrt(m^2 - omega^2)`.
