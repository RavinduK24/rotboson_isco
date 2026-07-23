# Self-Interaction Potentials for ROTBOSON

## Overview
Added support for quartic (`λ₄|φ|⁴/2`), sextic (`λ₆|φ|⁶/3`), and axion
(`m²f_a²[1−cos(φ/f_a)]`) self-interaction potentials to the rotational
boson star code, selected via the `potential_type` parameter.

## Files Modified

### New Files
- **src/potential.h** — Header for `compute_potential()`, exposes
  `MKL_INT type` dispatch with output pointers for V, dV/d|φ|², d²V/d|φ|²².
- **src/potential.c** — Implementation with sinc-safe axion branch for r→0.

### Parameter Infrastructure
- **src/param.h** — Added `potential_type` (MKL_INT, 0–3),
  `lambda_4`, `lambda_6`, `f_axion` (double) in both `#ifdef MAIN_FILE`
  and `#else` extern blocks.
- **src/parser.c** — Reads + validates `potential_type ∈ [0,3]`;
  reads `lambda_4`, `lambda_6`, `f_axion` with libconfig.
- **src/main.c** — Prints the active potential type and coupling value.

### Right-Hand Side (RHS)
- **src/rhs_vars.c** — Calls `compute_potential()` after `phi2` is computed;
  replaces `m2*phi2` → `V_val` and `m2` → `dV_val` in all 6 grid equations.

### Jacobian (CSR)
- **src/csr_vars.c** — All 5 Jacobian functions updated:
  - Added `#include "param.h"`, `#include "potential.h"` at top
  - Added `compute_potential()` call after `double phi2 = phi * phi;`
  - **Metric-row × a-col** (grids 1,3 → grid 4): `m2*phi2` → `V_val`
  - **Metric-row × ψ-col** (grids 1,3 → grid 5): `m2` → `dV_val`
  - **KG-row × a-col** (grid 5 → grid 4): `m2` → `dV_val`
  - **KG-row × ψ-diag** (grid 5 → grid 5): `m2` → `dV_val + 2·d²V·|φ|²`
  - **λ-row × ψ-col** (grid 6 → grid 5): `m2` → `dV_val` (both 2nd/4th order)
  - **λ-row × λ-diag** (submatrix 6, 4th‑order only): `m2·|φ|²` → `V_val`
  - **λ-row cross-term** (submatrix 3, 4th‑order): `r^(l-1)²·r²·λ·m²·ψ²` → `V_val·λ`

### Analysis
- **src/analysis.c** — GRV2, GRV3, and Komar‑J volume integrands call
  `compute_potential()` per grid point; `m²` → `dV_val`.

### Build System
- **Makefile** — Added `src/potential.c` → `obj/potential.o` to `SRCS`.

## Potential Selection Rules
| type | Name    | V(|φ|²)                    | dV/d|φ|²                 | d²V/d|φ|²²       |
|------|---------|----------------------------|--------------------------|-------------------|
| 0    | Free    | `m²|φ|²`                  | `m²`                     | `0`               |
| 1    | Quartic | `m²|φ|² + ½λ₄|φ|⁴`       | `m² + λ₄|φ|²`           | `λ₄`              |
| 2    | Sextic  | `m²|φ|² + ⅓λ₆|φ|⁶`       | `m² + λ₆|φ|⁴`           | `2λ₆|φ|²`         |
| 3    | Axion   | `m²f_a²[1−cos(φ/f_a)]`    | `½m² sinc(φ/f_a)`        | analytic (r→0 safe) |

## Remaining Work (optional)
- 2nd‑order λ-diagonal Jacobian terms for type ≠ 0 (minor, 2nd‑order
  stencil is low‑precision; 4th‑order is fully handled).
