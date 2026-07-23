#!/usr/bin/env python3
"""Standalone circular-orbit and ISCO scanner for ROTBOSON outputs."""
from __future__ import annotations

import argparse
import csv
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import numpy as np
from scipy.interpolate import CubicSpline, PchipInterpolator
from scipy.optimize import brentq


REQUIRED_GRID_FILES = (
    "sph_rr.asc",
    "sph_th.asc",
    "sph_log_alpha_f.asc",
    "sph_beta_f.asc",
    "sph_log_h_f.asc",
    "sph_log_a_f.asc",
)
LEGACY_RE = re.compile(
    r"l=(?P<ell>\d+),w=(?P<omega>[0-9.Ee+-]+),dr=(?P<dr>[0-9.Ee+-]+),N=(?P<n>\d+)"
)
HBAR_EV_S = 6.582119569e-16
HBAR_C_KM_EV = 1.973269804e-10


@dataclass
class MetricGrid:
    r: np.ndarray
    theta: np.ndarray
    gtt: np.ndarray
    gtphi: np.ndarray
    gphiphi: np.ndarray
    grr: np.ndarray
    gthetatheta: np.ndarray
    alpha: np.ndarray
    beta: np.ndarray


@dataclass
class StabilityClassification:
    status: str
    roots: list[dict[str, float]]
    isco_std: dict[str, float] | None
    isco_theo: dict[str, float] | None
    topology: str
    message: str


def read_metadata(path: Path) -> dict[str, str]:
    metadata: dict[str, str] = {}
    if not path.exists():
        return metadata
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        metadata[key.strip()] = value.strip()
    return metadata


def read_numeric(path: Path) -> np.ndarray:
    data = np.loadtxt(path, dtype=float)
    if data.size == 0 or not np.all(np.isfinite(data)):
        raise ValueError(f"empty or non-finite numeric data in {path}")
    return np.asarray(data, dtype=float)


def read_last(path: Path) -> float:
    return float(read_numeric(path).ravel()[-1])


def discover_solutions(roots: Iterable[Path]) -> list[Path]:
    found: set[Path] = set()
    marker = REQUIRED_GRID_FILES[0]
    for root in roots:
        root = root.resolve()
        if root.is_file() and root.name == marker:
            found.add(root.parent)
        elif root.is_dir():
            if (root / marker).exists() or (root / "run_metadata.txt").exists() or any((root / name).exists() for name in REQUIRED_GRID_FILES):
                found.add(root)
            for candidate in root.rglob(marker):
                found.add(candidate.parent)
            for candidate in root.rglob("run_metadata.txt"):
                found.add(candidate.parent)
    return sorted(found)


def load_metric_grid(directory: Path) -> MetricGrid:
    arrays = {name: read_numeric(directory / name) for name in REQUIRED_GRID_FILES}
    shape = arrays[REQUIRED_GRID_FILES[0]].shape
    if len(shape) != 2 or min(shape) < 5:
        raise ValueError(f"spherical grids must be two-dimensional and at least 5x5, got {shape}")
    if any(value.shape != shape for value in arrays.values()):
        raise ValueError("spherical grid files have inconsistent shapes")

    rr = arrays["sph_rr.asc"]
    theta = arrays["sph_th.asc"]
    log_alpha = arrays["sph_log_alpha_f.asc"]
    beta = arrays["sph_beta_f.asc"]
    log_h = arrays["sph_log_h_f.asc"]
    log_a = arrays["sph_log_a_f.asc"]
    r = rr[:, -1]
    th = theta[0, :]
    if not np.all(np.diff(r) > 0.0) or not np.all(np.diff(th) > 0.0):
        raise ValueError("radial and angular coordinates must be strictly increasing")
    if not math.isclose(float(th[-1]), 0.5 * math.pi, rel_tol=0.0, abs_tol=1.0e-7):
        raise ValueError("last angular column is not the equator")

    alpha = np.exp(log_alpha)
    h = np.exp(log_h)
    a = np.exp(log_a)
    rho2 = rr * rr * np.sin(theta) ** 2
    gphiphi = rho2 * h * h
    return MetricGrid(
        r=r,
        theta=th,
        gtt=-alpha * alpha + gphiphi * beta * beta,
        gtphi=gphiphi * beta,
        gphiphi=gphiphi,
        grr=a * a,
        gthetatheta=a * a * rr * rr,
        alpha=alpha,
        beta=beta,
    )


def _spline_derivatives(r: np.ndarray, values: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    spline = CubicSpline(r, values, bc_type="not-a-knot")
    return spline(r, 1), spline(r, 2)


def _effective_potential_second_derivative(
    energy: float,
    angular_momentum: float,
    metric: tuple[float, float, float],
    first: tuple[float, float, float],
    second: tuple[float, float, float],
) -> float:
    a, b, c = metric
    ap, bp, cp = first
    app, bpp, cpp = second
    numerator = energy * energy * c + 2.0 * energy * angular_momentum * b + angular_momentum**2 * a
    numerator_p = energy * energy * cp + 2.0 * energy * angular_momentum * bp + angular_momentum**2 * ap
    numerator_pp = energy * energy * cpp + 2.0 * energy * angular_momentum * bpp + angular_momentum**2 * app
    denominator = b * b - a * c
    denominator_p = 2.0 * b * bp - ap * c - a * cp
    denominator_pp = 2.0 * (bp * bp + b * bpp) - app * c - 2.0 * ap * cp - a * cpp
    return (
        numerator_pp / denominator
        - numerator * denominator_pp / denominator**2
        - 2.0 * numerator_p * denominator_p / denominator**2
        + 2.0 * numerator * denominator_p**2 / denominator**3
    )


def _vertical_second_derivative(
    grid: MetricGrid, radial_index: int, energy: float, angular_momentum: float
) -> float:
    count = min(7, grid.theta.size)
    indices = np.arange(grid.theta.size - count, grid.theta.size)
    delta2 = (0.5 * math.pi - grid.theta[indices]) ** 2
    values: list[float] = []
    for j in indices:
        a = grid.gtt[radial_index, j]
        b = grid.gtphi[radial_index, j]
        c = grid.gphiphi[radial_index, j]
        denominator = b * b - a * c
        values.append(
            -1.0
            + (energy * energy * c + 2.0 * energy * angular_momentum * b + angular_momentum**2 * a)
            / denominator
        )
    degree = min(3, count - 1)
    coefficients = np.polynomial.polynomial.polyfit(delta2, np.asarray(values), degree)
    return 2.0 * float(coefficients[1])


def circular_orbit_profiles(grid: MetricGrid, angular_momentum_star: float) -> dict[str, dict[str, np.ndarray]]:
    r = grid.r
    eq = -1
    gtt = grid.gtt[:, eq]
    gtphi = grid.gtphi[:, eq]
    gphiphi = grid.gphiphi[:, eq]
    grr = grid.grr[:, eq]
    alpha = grid.alpha[:, eq]
    beta = grid.beta[:, eq]
    derivatives = [_spline_derivatives(r, component) for component in (gtt, gtphi, gphiphi)]
    gtt_r, gtt_rr = derivatives[0]
    gtphi_r, gtphi_rr = derivatives[1]
    gphiphi_r, gphiphi_rr = derivatives[2]
    discriminant = gtphi_r * gtphi_r - gtt_r * gphiphi_r
    scale = np.maximum.reduce((gtphi_r * gtphi_r, np.abs(gtt_r * gphiphi_r), np.full_like(r, 1.0e-30)))

    profiles: dict[str, dict[str, np.ndarray]] = {}
    for sign, formula_name in ((1.0, "plus"), (-1.0, "minus")):
        omega = np.full_like(r, np.nan)
        orbit_mask = (discriminant > 1.0e-12 * scale) & (np.abs(gphiphi_r) > 1.0e-14)
        omega[orbit_mask] = (-gtphi_r[orbit_mask] + sign * np.sqrt(discriminant[orbit_mask])) / gphiphi_r[orbit_mask]
        norm = -(gtt + 2.0 * omega * gtphi + omega * omega * gphiphi)
        valid = orbit_mask & np.isfinite(norm) & (norm > 1.0e-12) & (gphiphi > 0.0) & (grr > 0.0)
        ut = np.full_like(r, np.nan)
        energy = np.full_like(r, np.nan)
        angular_momentum = np.full_like(r, np.nan)
        ut[valid] = 1.0 / np.sqrt(norm[valid])
        energy[valid] = -(gtt[valid] + omega[valid] * gtphi[valid]) * ut[valid]
        angular_momentum[valid] = (gtphi[valid] + omega[valid] * gphiphi[valid]) * ut[valid]

        radial2 = np.full_like(r, np.nan)
        vertical2 = np.full_like(r, np.nan)
        for i in np.flatnonzero(valid):
            potential_rr = _effective_potential_second_derivative(
                energy[i], angular_momentum[i],
                (gtt[i], gtphi[i], gphiphi[i]),
                (gtt_r[i], gtphi_r[i], gphiphi_r[i]),
                (gtt_rr[i], gtphi_rr[i], gphiphi_rr[i]),
            )
            radial2[i] = -potential_rr / (2.0 * grr[i] * ut[i] * ut[i])
            if grid.theta.size >= 5 and i > 0:
                potential_tt = _vertical_second_derivative(grid, i, energy[i], angular_momentum[i])
                vertical2[i] = -potential_tt / (2.0 * grid.gthetatheta[i, eq] * ut[i] * ut[i])

        if abs(angular_momentum_star) > 1.0e-12:
            finite_omega = omega[np.isfinite(omega)]
            representative = float(np.nanmedian(finite_omega[-max(3, finite_omega.size // 10):])) if finite_omega.size else sign
            branch = "co" if representative * angular_momentum_star > 0.0 else "counter"
        else:
            branch = formula_name
        profiles[branch] = {
            "r": r.copy(),
            "valid": valid,
            "omega": omega,
            "E": energy,
            "L": angular_momentum,
            "ut": ut,
            "zamo_velocity": (omega + beta) * np.sqrt(gphiphi) / alpha,
            "efficiency": 1.0 - energy,
            "radial_epicyclic2": radial2,
            "vertical_epicyclic2": vertical2,
            "circumferential_radius": np.sqrt(gphiphi),
        }
    return profiles


def _root_interpolator(x: np.ndarray, y: np.ndarray) -> tuple[PchipInterpolator, list[tuple[float, float]]]:
    interpolator = PchipInterpolator(x, y, extrapolate=False)
    brackets: list[tuple[float, float]] = []
    for left, right, yl, yr in zip(x[:-1], x[1:], y[:-1], y[1:]):
        if yl == 0.0:
            brackets.append((left, left))
        elif yl * yr < 0.0:
            brackets.append((left, right))
    if y[-1] == 0.0:
        brackets.append((x[-1], x[-1]))
    return interpolator, brackets


def _theoretical_isco_root(
    roots: list[dict[str, float]],
    r: np.ndarray,
    kappa2: np.ndarray,
    tolerance: float,
) -> dict[str, float] | None:
    if kappa2[0] > tolerance:
        return None
    for root in sorted(roots, key=lambda item: item["coordinate_radius"]):
        index = int(np.clip(np.searchsorted(r, root["coordinate_radius"]), 1, r.size - 1))
        inner_value = kappa2[index - 1]
        outer_value = kappa2[index]
        if inner_value <= tolerance and outer_value > tolerance:
            return root
    return None


def _existence_boundary_root(r: np.ndarray) -> dict[str, float]:
    spacing = float(r[1] - r[0]) if r.size > 1 else math.nan
    return {
        "coordinate_radius": float(r[0]),
        "root_residual": math.nan,
        "numerical_uncertainty": 0.5 * spacing,
        "selection_kind": "circular_orbit_existence_boundary",
    }


def classify_stability(profile: dict[str, np.ndarray]) -> StabilityClassification:
    if profile["r"].size < 12:
        return StabilityClassification("insufficient_resolution", [], None, None, "insufficient_resolution", "Too few radial points.")
    valid_indices = np.flatnonzero(profile["valid"] & np.isfinite(profile["radial_epicyclic2"]))
    if valid_indices.size == 0:
        return StabilityClassification("no_timelike_orbit", [], None, None, "no_timelike_orbit", "No valid circular timelike orbit points.")
    if valid_indices.size < 10:
        return StabilityClassification("insufficient_resolution", [], None, None, "insufficient_resolution", "Too few valid circular timelike orbit points.")
    if np.any(np.diff(valid_indices) != 1):
        return StabilityClassification(
            "noncontiguous_orbit_domain", [], None, None, "noncontiguous_orbit_domain",
            "Valid circular-orbit points are not contiguous; this is flagged for further exploration."
        )
    starts_at_center = valid_indices[0] <= 1
    r = profile["r"][valid_indices]
    kappa2 = profile["radial_epicyclic2"][valid_indices]
    tolerance = max(1.0e-12, 1.0e-8 * float(np.nanmax(np.abs(kappa2))))
    if kappa2[-1] <= tolerance:
        return StabilityClassification(
            "outer_unstable_invalid", [], None, None, "outer_unstable_invalid",
            "Outer circular-orbit branch is not stable, contrary to the Newtonian large-radius limit."
        )

    interpolator, brackets = _root_interpolator(r, kappa2)
    roots: list[dict[str, float]] = []
    for left, right in brackets:
        root = left if left == right else float(brentq(interpolator, left, right))
        local = int(np.clip(np.searchsorted(r, root), 1, r.size - 1))
        linear = r[local - 1] - kappa2[local - 1] * (r[local] - r[local - 1]) / (kappa2[local] - kappa2[local - 1])
        spacing = r[local] - r[local - 1]
        roots.append(
            {
                "coordinate_radius": root,
                "root_residual": abs(float(interpolator(root))),
                "numerical_uncertainty": 0.5 * spacing + abs(root - linear),
                "selection_kind": "marginal_stability_crossing",
            }
        )
    roots.sort(key=lambda item: item["coordinate_radius"], reverse=True)
    isco_theo = _theoretical_isco_root(roots, r, kappa2, tolerance)
    if roots:
        isco_std = roots[0]
        if kappa2[0] > tolerance:
            return StabilityClassification(
                "found", roots, isco_std, None, "inner_stable_region_to_center",
                "Innermost stable region extends to the center; no ISCO_theo exists."
            )
        if isco_theo is isco_std:
            return StabilityClassification(
                "found", roots, isco_std, isco_std, "standard_equals_theoretical_isco",
                "Only one relevant ISCO boundary; ISCO_std and ISCO_theo are the same."
            )
        if isco_theo is not None:
            return StabilityClassification(
                "found", roots, isco_std, isco_theo, "bounded_inner_stable_region",
                "A bounded inner stable region exists; ISCO_theo is its inner stability boundary."
            )
        return StabilityClassification(
            "found", roots, isco_std, None, "standard_isco_only",
            "Standard disk-facing ISCO exists; no theoretical inner stable boundary was selected."
        )
    if np.all(kappa2 > -tolerance):
        if starts_at_center:
            return StabilityClassification(
                "all_stable_no_isco", [], None, None, "all_stable_to_center",
                "All resolved circular orbits are stable down to the center; no ISCO exists."
            )
        boundary = _existence_boundary_root(r)
        return StabilityClassification(
            "found", [], boundary, boundary, "stable_to_no_circular_orbit",
            "Stable circular orbits terminate at an existence boundary; ISCO_std and ISCO_theo are the same."
        )
    return StabilityClassification(
        "unresolved_boundary", [], None, None, "unresolved_boundary",
        "Stability changes could not be classified robustly."
    )


def interpolate_profile(profile: dict[str, np.ndarray], radius: float, key: str) -> float:
    values = profile[key]
    mask = profile["valid"] & np.isfinite(values)
    return float(PchipInterpolator(profile["r"][mask], values[mask])(radius))


def run_properties(directory: Path) -> dict[str, Any]:
    metadata = read_metadata(directory / "run_metadata.txt")
    legacy = LEGACY_RE.search(directory.name)
    result: dict[str, Any] = {
        "potential": metadata.get("potential", "free"),
        "coupling_name": metadata.get("coupling_name", "none"),
        "coupling_value": float(metadata.get("coupling_value", "0")),
        "m": float(metadata.get("m", "1")),
        "ell": int(metadata.get("l", legacy.group("ell") if legacy else "0")),
        "omega_star": float(metadata.get("omega", legacy.group("omega") if legacy else "nan")),
        "convergence_status": metadata.get("convergence_status", "legacy_unknown"),
    }
    if (directory / "w_f.asc").exists():
        result["omega_star"] = read_last(directory / "w_f.asc")
    if "M_Komar" in metadata:
        result["mass"] = float(metadata["M_Komar"])
    elif (directory / "M_Komar1.asc").exists() and (directory / "M_Komar2.asc").exists():
        result["mass"] = 0.5 * (read_last(directory / "M_Komar1.asc") + read_last(directory / "M_Komar2.asc"))
    else:
        raise ValueError("missing Komar mass")
    if "J_Komar" in metadata:
        result["angular_momentum_star"] = float(metadata["J_Komar"])
    elif (directory / "J_Komar1.asc").exists() and (directory / "J_Komar2.asc").exists():
        result["angular_momentum_star"] = 0.5 * (read_last(directory / "J_Komar1.asc") + read_last(directory / "J_Komar2.asc"))
    else:
        raise ValueError("missing Komar angular momentum")
    if not math.isfinite(result["mass"]) or result["mass"] <= 0.0:
        raise ValueError("Komar mass must be finite and positive")
    if not math.isfinite(result["angular_momentum_star"]):
        raise ValueError("Komar angular momentum must be finite")
    return result


def _base_row(directory: Path, properties: dict[str, Any], branch: str, status: str) -> dict[str, Any]:
    return {
        "directory": str(directory),
        "potential": properties["potential"],
        "coupling_name": properties["coupling_name"],
        "coupling_value": properties["coupling_value"],
        "ell": properties["ell"],
        "omega_star": properties["omega_star"],
        "mass": properties["mass"],
        "angular_momentum_star": properties["angular_momentum_star"],
        "orbital_branch": branch,
        "status": status,
        "convergence_status": properties.get("convergence_status", "unknown"),
    }


def orbit_row(
    directory: Path,
    properties: dict[str, Any],
    branch: str,
    status: str,
    profile: dict[str, np.ndarray] | None,
    root: dict[str, float] | None,
    boson_mass_ev: float | None,
) -> dict[str, Any]:
    row = _base_row(directory, properties, branch, status)
    columns = (
        "coordinate_radius", "circumferential_radius", "coordinate_radius_over_M",
        "circumferential_radius_over_M", "orbital_angular_frequency", "cyclic_frequency",
        "M_Omega", "E", "L_over_M", "ut", "zamo_velocity", "efficiency",
        "radial_epicyclic2", "vertical_epicyclic2", "vertical_epicyclic_frequency",
        "root_residual", "numerical_uncertainty", "selection_kind",
    )
    row.update({name: math.nan for name in columns})
    row["selection_kind"] = "none"
    if boson_mass_ev is not None:
        row.update({name: math.nan for name in (
            "coordinate_radius_km", "circumferential_radius_km",
            "cyclic_frequency_hz", "vertical_epicyclic_frequency_hz",
        )})
    if root is None or profile is None:
        return row
    radius = root["coordinate_radius"]
    mass = properties["mass"]
    omega = interpolate_profile(profile, radius, "omega")
    vertical2 = interpolate_profile(profile, radius, "vertical_epicyclic2")
    row.update(
        {
            "coordinate_radius": radius,
            "circumferential_radius": interpolate_profile(profile, radius, "circumferential_radius"),
            "coordinate_radius_over_M": radius / mass,
            "orbital_angular_frequency": omega,
            "cyclic_frequency": abs(omega) / (2.0 * math.pi),
            "M_Omega": mass * omega,
            "E": interpolate_profile(profile, radius, "E"),
            "L_over_M": interpolate_profile(profile, radius, "L") / mass,
            "ut": interpolate_profile(profile, radius, "ut"),
            "zamo_velocity": interpolate_profile(profile, radius, "zamo_velocity"),
            "efficiency": interpolate_profile(profile, radius, "efficiency"),
            "radial_epicyclic2": interpolate_profile(profile, radius, "radial_epicyclic2"),
            "vertical_epicyclic2": vertical2,
            "vertical_epicyclic_frequency": math.sqrt(vertical2) / (2.0 * math.pi) if vertical2 >= 0.0 else math.nan,
            "root_residual": root["root_residual"],
            "numerical_uncertainty": root["numerical_uncertainty"],
            "selection_kind": root.get("selection_kind", "unknown"),
        }
    )
    row["circumferential_radius_over_M"] = row["circumferential_radius"] / mass
    if boson_mass_ev is not None:
        length_scale = properties["m"] * HBAR_C_KM_EV / boson_mass_ev
        frequency_scale = boson_mass_ev / (properties["m"] * HBAR_EV_S)
        row["coordinate_radius_km"] = radius * length_scale
        row["circumferential_radius_km"] = row["circumferential_radius"] * length_scale
        row["cyclic_frequency_hz"] = abs(omega) * frequency_scale / (2.0 * math.pi)
        row["vertical_epicyclic_frequency_hz"] = math.sqrt(vertical2) * frequency_scale / (2.0 * math.pi) if vertical2 >= 0.0 else math.nan
    return row


def add_summary_isco_columns(
    row: dict[str, Any],
    directory: Path,
    properties: dict[str, Any],
    branch: str,
    profile: dict[str, np.ndarray],
    classification: StabilityClassification,
    boson_mass_ev: float | None,
) -> dict[str, Any]:
    aliases = {
        "isco_std": classification.isco_std,
        "isco_theo": classification.isco_theo,
    }
    fields = (
        "coordinate_radius", "circumferential_radius", "coordinate_radius_over_M",
        "circumferential_radius_over_M", "orbital_angular_frequency", "cyclic_frequency",
        "M_Omega", "E", "L_over_M", "ut", "zamo_velocity", "efficiency",
        "radial_epicyclic2", "vertical_epicyclic2", "vertical_epicyclic_frequency",
        "root_residual", "numerical_uncertainty", "selection_kind",
    )
    if boson_mass_ev is not None:
        fields = fields + (
            "coordinate_radius_km", "circumferential_radius_km",
            "cyclic_frequency_hz", "vertical_epicyclic_frequency_hz",
        )
    for prefix, root in aliases.items():
        selected = orbit_row(directory, properties, branch, classification.status, profile, root, boson_mass_ev)
        for field in fields:
            row[f"{prefix}_{field}"] = selected.get(field, math.nan)
    return row


def write_csv(path: Path, rows: list[dict[str, Any]], fallback_fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0]) if rows else fallback_fields
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def safe_name(path: Path) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", path.name)


def export_profile(path: Path, profile: dict[str, np.ndarray]) -> None:
    fields = [key for key in profile if key != "valid"]
    rows = []
    for index in range(profile["r"].size):
        row = {key: profile[key][index] for key in fields}
        row["valid"] = bool(profile["valid"][index])
        rows.append(row)
    write_csv(path, rows, fields + ["valid"])


def make_plots(rows: list[dict[str, Any]], output_dir: Path, plot_format: str, dpi: int) -> None:
    found = [row for row in rows if row["status"] == "found"]
    if not found:
        return
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    groups: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for row in found:
        groups.setdefault((row["potential"], row["orbital_branch"]), []).append(row)
    for y, label, filename in (
        ("circumferential_radius_over_M", r"$R_{\rm ISCO}/M$", "isco_radius_vs_frequency"),
        ("M_Omega", r"$M\Omega_{\rm ISCO}$", "isco_angular_frequency"),
        ("efficiency", r"$1-E_{\rm ISCO}$", "isco_efficiency"),
    ):
        fig, ax = plt.subplots(figsize=(7.0, 4.8))
        for (potential, branch), group in sorted(groups.items()):
            ordered = sorted(group, key=lambda item: item["omega_star"])
            ax.plot([item["omega_star"] for item in ordered], [item[y] for item in ordered], "o-", label=f"{potential} {branch}")
        ax.set_xlabel(r"star frequency $\omega$")
        ax.set_ylabel(label)
        ax.grid(alpha=0.3)
        ax.legend(fontsize=8)
        fig.tight_layout()
        fig.savefig(output_dir / f"{filename}.{plot_format}", dpi=dpi)
        plt.close(fig)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_roots", nargs="+", type=Path, help="ROTBOSON run directories or roots to scan")
    parser.add_argument("--output-dir", required=True, type=Path, help="directory for CSV tables and plots")
    parser.add_argument("--boson-mass-ev", type=float, default=None, help="physical scalar mass in eV")
    parser.add_argument("--export-profiles", action="store_true", help="write one radial orbit-profile CSV per run and branch")
    parser.add_argument("--strict", action="store_true", help="return nonzero when any run is invalid or unresolved")
    parser.add_argument("--no-plots", action="store_true")
    parser.add_argument("--plot-format", choices=("png", "pdf", "svg"), default="png")
    parser.add_argument("--dpi", type=int, default=180)
    args = parser.parse_args()
    if args.boson_mass_ev is not None and args.boson_mass_ev <= 0.0:
        parser.error("--boson-mass-ev must be positive")
    return args


def main() -> int:
    args = parse_args()
    directories = discover_solutions(args.input_roots)
    if not directories:
        print("No ROTBOSON spherical-grid solutions found.", file=sys.stderr)
        return 2
    args.output_dir.mkdir(parents=True, exist_ok=True)
    summary_rows: list[dict[str, Any]] = []
    marginal_rows: list[dict[str, Any]] = []
    diagnostics: list[dict[str, Any]] = []
    strict_failure = False

    for directory in directories:
        try:
            missing = [name for name in REQUIRED_GRID_FILES if not (directory / name).exists()]
            if missing:
                raise ValueError(f"missing {', '.join(missing)}")
            properties = run_properties(directory)
            grid = load_metric_grid(directory)
            profiles = circular_orbit_profiles(grid, properties["angular_momentum_star"])
            for branch, profile in profiles.items():
                classification = classify_stability(profile)
                status = classification.status
                roots = classification.roots
                summary = orbit_row(directory, properties, branch, status, profile, classification.isco_std, args.boson_mass_ev)
                summary["stability_topology"] = classification.topology
                summary["classification_message"] = classification.message
                summary_rows.append(add_summary_isco_columns(
                    summary, directory, properties, branch, profile, classification, args.boson_mass_ev
                ))
                for index, root in enumerate(roots):
                    row = orbit_row(directory, properties, branch, "found", profile, root, args.boson_mass_ev)
                    row["crossing_index_from_outside"] = index
                    row["disk_facing_isco"] = index == 0
                    row["isco_std"] = root is classification.isco_std
                    row["isco_theo"] = root is classification.isco_theo
                    marginal_rows.append(row)
                valid_count = int(np.count_nonzero(profile["valid"]))
                diagnostics.append(
                    {
                        **_base_row(directory, properties, branch, status),
                        "radial_points": grid.r.size,
                        "angular_points": grid.theta.size,
                        "valid_orbit_points": valid_count,
                        "marginal_orbit_count": len(roots),
                        "r_min": float(grid.r[0]),
                        "r_max": float(grid.r[-1]),
                        "stability_topology": classification.topology,
                        "message": classification.message,
                    }
                )
                if args.export_profiles:
                    export_profile(args.output_dir / "profiles" / f"{safe_name(directory)}_{branch}.csv", profile)
                strict_failure |= status in {
                    "invalid_solution", "insufficient_resolution", "unresolved_boundary",
                    "outer_unstable_invalid", "noncontiguous_orbit_domain",
                }
                strict_failure |= properties.get("convergence_status") == "not_converged"
        except Exception as exc:  # keep a complete scan unless strict exit is requested
            properties = {
                "potential": "unknown", "coupling_name": "unknown", "coupling_value": math.nan,
                "ell": 0, "omega_star": math.nan, "mass": math.nan, "angular_momentum_star": math.nan,
            }
            summary_rows.append(orbit_row(directory, properties, "unknown", "invalid_solution", None, None, args.boson_mass_ev))
            diagnostics.append(
                {
                    **_base_row(directory, properties, "unknown", "invalid_solution"),
                    "radial_points": 0, "angular_points": 0, "valid_orbit_points": 0,
                    "marginal_orbit_count": 0, "r_min": math.nan, "r_max": math.nan,
                    "message": str(exc),
                }
            )
            strict_failure = True

    write_csv(args.output_dir / "isco_summary.csv", summary_rows, ["directory", "status"])
    write_csv(args.output_dir / "marginal_orbits.csv", marginal_rows, ["directory", "orbital_branch", "status"])
    write_csv(args.output_dir / "scan_diagnostics.csv", diagnostics, ["directory", "status", "message"])
    if not args.no_plots:
        make_plots(summary_rows, args.output_dir, args.plot_format, args.dpi)
    print(f"Scanned {len(directories)} solution(s); wrote results to {args.output_dir}")
    return 1 if args.strict and strict_failure else 0


if __name__ == "__main__":
    raise SystemExit(main())
