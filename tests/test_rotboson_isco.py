from __future__ import annotations

import math
import tempfile
import unittest
from pathlib import Path

import numpy as np

from scripts.rotboson_isco import (
    MetricGrid,
    circular_orbit_profiles,
    classify_stability,
    discover_solutions,
    interpolate_profile,
    orbit_row,
)


def metric_grid(
    r: np.ndarray,
    theta: np.ndarray,
    gtt: np.ndarray,
    gtphi: np.ndarray,
    gphiphi: np.ndarray,
    grr: np.ndarray,
    gthetatheta: np.ndarray,
) -> MetricGrid:
    alpha = np.sqrt(np.maximum(-gtt + gtphi * gtphi / np.maximum(gphiphi, 1.0e-30), 1.0e-30))
    beta = np.divide(gtphi, gphiphi, out=np.zeros_like(gtphi), where=gphiphi != 0.0)
    return MetricGrid(r, theta, gtt, gtphi, gphiphi, grr, gthetatheta, alpha, beta)


def schwarzschild_grid(mass: float = 1.0) -> MetricGrid:
    r = np.linspace(3.05 * mass, 20.0 * mass, 600)
    theta = np.linspace(0.05, 0.5 * math.pi, 41)
    rr, th = np.meshgrid(r, theta, indexing="ij")
    f = 1.0 - 2.0 * mass / rr
    return metric_grid(
        r, theta, -f, np.zeros_like(rr), rr * rr * np.sin(th) ** 2,
        1.0 / f, rr * rr,
    )


def kerr_grid(spin: float, mass: float = 1.0) -> MetricGrid:
    r = np.linspace(2.05 * mass, 20.0 * mass, 900)
    theta = np.linspace(0.05, 0.5 * math.pi, 51)
    rr, th = np.meshgrid(r, theta, indexing="ij")
    sigma = rr * rr + spin * spin * np.cos(th) ** 2
    delta = rr * rr - 2.0 * mass * rr + spin * spin
    sin2 = np.sin(th) ** 2
    gtt = -(1.0 - 2.0 * mass * rr / sigma)
    gtphi = -2.0 * mass * spin * rr * sin2 / sigma
    gphiphi = (rr * rr + spin * spin + 2.0 * mass * spin * spin * rr * sin2 / sigma) * sin2
    return metric_grid(r, theta, gtt, gtphi, gphiphi, sigma / delta, sigma)


def kerr_isco(mass: float, spin: float, prograde: bool) -> float:
    a = abs(spin) / mass
    z1 = 1.0 + (1.0 - a * a) ** (1.0 / 3.0) * ((1.0 + a) ** (1.0 / 3.0) + (1.0 - a) ** (1.0 / 3.0))
    z2 = math.sqrt(3.0 * a * a + z1 * z1)
    sign = -1.0 if prograde else 1.0
    return mass * (3.0 + z2 + sign * math.sqrt((3.0 - z1) * (3.0 + z1 + 2.0 * z2)))


class IscoMathTests(unittest.TestCase):
    def test_schwarzschild_isco_invariants(self) -> None:
        profiles = circular_orbit_profiles(schwarzschild_grid(), 0.0)
        profile = profiles["plus"]
        classification = classify_stability(profile)
        self.assertEqual(classification.status, "found")
        self.assertIsNotNone(classification.isco_std)
        radius = float(classification.isco_std["coordinate_radius"])
        self.assertAlmostEqual(radius, 6.0, delta=2.0e-3)
        self.assertAlmostEqual(interpolate_profile(profile, radius, "omega"), 1.0 / (6.0 * math.sqrt(6.0)), delta=2.0e-5)
        self.assertAlmostEqual(interpolate_profile(profile, radius, "E"), math.sqrt(8.0 / 9.0), delta=2.0e-5)
        self.assertAlmostEqual(interpolate_profile(profile, radius, "L"), 2.0 * math.sqrt(3.0), delta=3.0e-4)
        self.assertAlmostEqual(
            math.sqrt(interpolate_profile(profile, radius, "vertical_epicyclic2")),
            interpolate_profile(profile, radius, "omega"),
            delta=3.0e-5,
        )
        self.assertGreater(len(classification.roots), 0)

    def test_kerr_both_branches(self) -> None:
        spin = 0.5
        profiles = circular_orbit_profiles(kerr_grid(spin), spin)
        for branch, prograde in (("co", True), ("counter", False)):
            classification = classify_stability(profiles[branch])
            self.assertEqual(classification.status, "found")
            self.assertIsNotNone(classification.isco_std)
            self.assertAlmostEqual(
                float(classification.isco_std["coordinate_radius"]),
                kerr_isco(1.0, spin, prograde),
                delta=8.0e-3,
            )

    def test_minkowski_has_no_nontrivial_circular_branch(self) -> None:
        r = np.linspace(0.1, 10.0, 100)
        theta = np.linspace(0.05, 0.5 * math.pi, 21)
        rr, th = np.meshgrid(r, theta, indexing="ij")
        grid = metric_grid(
            r, theta, -np.ones_like(rr), np.zeros_like(rr), rr * rr * np.sin(th) ** 2,
            np.ones_like(rr), rr * rr,
        )
        for profile in circular_orbit_profiles(grid, 0.0).values():
            self.assertEqual(classify_stability(profile).status, "no_timelike_orbit")

    def test_multiple_crossings_selects_standard_and_theoretical_isco(self) -> None:
        r = np.linspace(1.0, 10.0, 301)
        profile = {
            "r": r,
            "valid": np.ones_like(r, dtype=bool),
            "radial_epicyclic2": (r - 3.0) * (r - 5.0) * (r - 7.0),
        }
        classification = classify_stability(profile)
        self.assertEqual(classification.status, "found")
        self.assertEqual(len(classification.roots), 3)
        self.assertIsNotNone(classification.isco_std)
        self.assertIsNotNone(classification.isco_theo)
        self.assertAlmostEqual(float(classification.isco_std["coordinate_radius"]), 7.0, places=10)
        self.assertAlmostEqual(float(classification.isco_theo["coordinate_radius"]), 3.0, delta=1.0e-5)

    def test_inner_stable_region_to_center_has_no_theoretical_isco(self) -> None:
        r = np.linspace(1.0, 10.0, 301)
        profile = {
            "r": r,
            "valid": np.ones_like(r, dtype=bool),
            "radial_epicyclic2": (r - 5.0) * (r - 7.0),
        }
        classification = classify_stability(profile)
        self.assertEqual(classification.status, "found")
        self.assertIsNotNone(classification.isco_std)
        self.assertIsNone(classification.isco_theo)
        self.assertAlmostEqual(float(classification.isco_std["coordinate_radius"]), 7.0, places=10)

    def test_all_stable_to_center_has_no_isco(self) -> None:
        r = np.linspace(1.0, 10.0, 301)
        profile = {"r": r, "valid": np.ones_like(r, dtype=bool), "radial_epicyclic2": np.ones_like(r)}
        classification = classify_stability(profile)
        self.assertEqual(classification.status, "all_stable_no_isco")
        self.assertEqual(classification.topology, "all_stable_to_center")
        self.assertIsNone(classification.isco_std)
        self.assertIsNone(classification.isco_theo)

    def test_single_marginal_boundary_counts_as_both_isco_definitions(self) -> None:
        r = np.linspace(1.0, 10.0, 301)
        profile = {
            "r": r,
            "valid": np.ones_like(r, dtype=bool),
            "radial_epicyclic2": r - 6.0,
        }
        classification = classify_stability(profile)
        self.assertEqual(classification.status, "found")
        self.assertEqual(classification.topology, "standard_equals_theoretical_isco")
        self.assertIs(classification.isco_std, classification.isco_theo)
        self.assertAlmostEqual(float(classification.isco_std["coordinate_radius"]), 6.0, places=10)

    def test_outer_unstable_branch_is_flagged(self) -> None:
        r = np.linspace(1.0, 10.0, 301)
        profile = {"r": r, "valid": np.ones_like(r, dtype=bool), "radial_epicyclic2": -np.ones_like(r)}
        classification = classify_stability(profile)
        self.assertEqual(classification.status, "outer_unstable_invalid")
        self.assertIsNone(classification.isco_std)
        self.assertIsNone(classification.isco_theo)

    def test_noncontiguous_orbit_domain_is_flagged(self) -> None:
        r = np.linspace(1.0, 10.0, 301)
        valid = np.ones_like(r, dtype=bool)
        valid[100:120] = False
        profile = {"r": r, "valid": valid, "radial_epicyclic2": np.ones_like(r)}
        classification = classify_stability(profile)
        self.assertEqual(classification.status, "noncontiguous_orbit_domain")
        self.assertIsNone(classification.isco_std)
        self.assertIsNone(classification.isco_theo)

    def test_stable_to_existence_boundary_counts_as_both_isco_definitions(self) -> None:
        r = np.linspace(1.0, 10.0, 301)
        valid = r >= 3.0
        profile = {"r": r, "valid": valid, "radial_epicyclic2": np.ones_like(r)}
        classification = classify_stability(profile)
        self.assertEqual(classification.status, "found")
        self.assertEqual(classification.topology, "stable_to_no_circular_orbit")
        self.assertIs(classification.isco_std, classification.isco_theo)
        self.assertAlmostEqual(float(classification.isco_std["coordinate_radius"]), r[valid][0], places=10)

    def test_low_resolution_is_reported(self) -> None:
        r = np.linspace(1.0, 10.0, 8)
        profile = {"r": r, "valid": np.ones_like(r, dtype=bool), "radial_epicyclic2": np.ones_like(r)}
        self.assertEqual(classify_stability(profile).status, "insufficient_resolution")

    def test_metadata_only_malformed_root_is_discovered(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "run_metadata.txt").write_text("format_version=1\n", encoding="utf-8")
            self.assertEqual(discover_solutions([root]), [root.resolve()])

    def test_physical_columns_are_opt_in(self) -> None:
        properties = {
            "potential": "free", "coupling_name": "none", "coupling_value": 0.0,
            "ell": 1, "omega_star": 0.9, "mass": 1.0, "angular_momentum_star": 0.1,
            "convergence_status": "converged", "m": 1.0,
        }
        dimensionless = orbit_row(Path("run"), properties, "co", "all_stable_no_isco", None, None, None)
        physical = orbit_row(Path("run"), properties, "co", "all_stable_no_isco", None, None, 1.0e-11)
        self.assertNotIn("coordinate_radius_km", dimensionless)
        self.assertIn("coordinate_radius_km", physical)


if __name__ == "__main__":
    unittest.main()
