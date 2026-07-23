# ISCO Definitions

This note records the ISCO classification rules used by `scripts/rotboson_isco.py`.
All region patterns below are read from large radius inward.

## Definitions

- `ISCO_std`: the standard disk-facing ISCO. It is the first boundary reached when moving inward from the outer Newtonian stable circular-orbit region.
- `ISCO_theo`: a theoretical innermost stable circular-orbit boundary. It exists only when a stable circular-orbit region has an actual smaller-radius termination. If a stable region extends to the center, `ISCO_theo` does not exist.
- `MSCO`: a marginally stable circular orbit where `kappa_r^2 = 0`.
- `ICO`: an existence boundary where circular timelike orbits stop existing. The code can use this as the common `ISCO_std = ISCO_theo` only when stable circular orbits terminate there without an MSCO crossing.

## Classification Rules

```text
stable -> center
```

- `status = all_stable_no_isco`
- `ISCO_std = NaN`
- `ISCO_theo = NaN`

```text
stable -> unstable
stable -> unstable -> no circular orbit
```

- `status = found`
- `ISCO_std = outer stability boundary`
- `ISCO_theo = ISCO_std`
- This counts as one ISCO value, reported in both columns.

```text
stable -> unstable -> stable -> center
stable -> unstable -> stable -> unstable -> stable -> center
```

- `status = found`
- `ISCO_std = outer stability boundary`
- `ISCO_theo = NaN`
- `stability_topology = inner_stable_region_to_center`
- The CSV message says the innermost stable region extends to the center.

```text
stable -> unstable -> stable -> unstable
```

- `status = found`
- `ISCO_std = first outer stability boundary`
- `ISCO_theo = inner stable-region lower boundary`
- `stability_topology = bounded_inner_stable_region`

```text
unstable -> ...
```

- This should not occur for the outer branch because the Newtonian large-radius limit must be stable.
- The scanner flags it with `status = outer_unstable_invalid`.
- `ISCO_std = NaN`
- `ISCO_theo = NaN`

```text
stable -> unresolved gap -> stable
```

- Non-contiguous valid circular-orbit data are not classified across the gap.
- The scanner flags it with `status = noncontiguous_orbit_domain`.
- `ISCO_std = NaN`
- `ISCO_theo = NaN`

```text
stable -> no circular orbit
```

- `status = found`
- `ISCO_std = circular-orbit existence boundary`
- `ISCO_theo = ISCO_std`
- This is an ICO-type ISCO and counts as one ISCO value.

## Current CSV Columns

`isco_summary.csv` keeps the unprefixed orbit columns as the standard/disk-facing value for backwards compatibility. It also writes explicit prefixed groups:

```text
isco_std_*
isco_theo_*
```

The CSV also includes:

```text
stability_topology
classification_message
```

These fields should be used when deciding whether `NaN` means no ISCO, an inner stable region reaches the center, or a numerical/topological case was flagged for later inspection.
