from __future__ import annotations

import importlib.util
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "validate_boson_stars", REPO / "scripts" / "validate_boson_stars.py"
)
assert SPEC and SPEC.loader
validation = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = validation
SPEC.loader.exec_module(validation)


def point(step: int, omega: float) -> validation.BranchPoint:
    return validation.BranchPoint(step, Path(f"solution_{step}"), omega, 1.0, 0.1, 0.01)


def write_values(path: Path, *values: float) -> None:
    path.write_text("\n".join(f"{value:.17E}" for value in values) + "\n", encoding="utf-8")


def make_solution(
    directory: Path,
    target: dict,
    grid: dict,
    observable_error: float = 1.0e-5,
) -> None:
    directory.mkdir(parents=True)
    mass = target["literature"]["mass"] * (1.0 + observable_error)
    angular = target["literature"]["angular_momentum"] * (1.0 + observable_error)
    dr = grid["r_max"] / grid["n"]
    (directory / "run_metadata.txt").write_text(
        "\n".join((
            "format_version=1", "potential=free", "convergence_status=converged",
            "error_code=0", f"l={target['ell']}", f"omega={target['omega']:.17E}",
            f"dr={dr:.17E}", f"NrInterior={grid['n']}",
            f"M_Komar={mass:.17E}", f"J_Komar={angular:.17E}",
            "GRV2=1.0E-8", "GRV3=1.0E-8",
        )) + "\n", encoding="utf-8"
    )
    write_values(directory / "M_Komar1.asc", mass * (1.0 + 1.0e-6))
    write_values(directory / "M_Komar2.asc", mass * (1.0 - 1.0e-6))
    write_values(directory / "M_ADM.asc", mass)
    write_values(directory / "J_Komar1.asc", angular * (1.0 + 1.0e-6))
    write_values(directory / "J_Komar2.asc", angular * (1.0 - 1.0e-6))
    write_values(directory / "Noether_charge.asc", angular * (1.0 - 1.0e-6) / target["ell"])
    write_values(directory / "phi_max.asc", 0.1)
    write_values(directory / "rr_phi_max.asc", 2.0)
    write_values(directory / "norm_f.asc", 1.0e-4, 1.0e-11)
    write_values(directory / "final_residual.asc", 1.0e-11)
    write_values(directory / "GRV2.asc", 1.0e-8)
    write_values(directory / "GRV3.asc", 1.0e-8)
    lapse = target["literature"].get("minus_gtt_origin", 0.5)
    write_values(directory / "sph_log_alpha_f.asc", 0.5 * math.log(lapse * (1.0 + observable_error)))


class ManifestTests(unittest.TestCase):
    def test_manifest_parses_and_routes_solvers(self) -> None:
        manifest = validation.load_manifest()
        self.assertEqual(len(manifest["targets"]), 4)
        self.assertEqual({target["solver"] for target in manifest["targets"]}, {"rotboson"})
        self.assertEqual(manifest["sequence_targets"][0]["solver"], "sphboson")
        self.assertFalse(manifest["sequence_targets"][0]["enabled_default"])
        self.assertAlmostEqual(4.0 * math.pi * 200.0, 2513.2741228718345)

    def test_grid_matrix_has_four_targets_and_sixteen_extra_solves(self) -> None:
        manifest = validation.load_manifest()
        targets = [target for target in manifest["targets"] if target["ell"] == 1]
        self.assertEqual(len(targets), 4)
        self.assertEqual(sum(len(target["grids"]) - 1 for target in targets), 16)
        profile = next(item for item in manifest["continuation_profiles"] if item["ell"] == 1)
        self.assertEqual(profile["n"], 256)
        self.assertEqual(profile["r_max"], 16.0)


class BranchTests(unittest.TestCase):
    def setUp(self) -> None:
        self.points = [point(i, omega) for i, omega in enumerate((0.95, 0.85, 0.70, 0.65, 0.72, 0.89, 0.92))]

    def test_turning_point_and_branch_detection(self) -> None:
        self.assertEqual(validation.turning_point_index(self.points), 3)
        self.assertTrue(validation.branch_phase_ready(self.points, "fundamental"))
        self.assertTrue(validation.branch_phase_ready(self.points, "third"))

    def test_exact_frequency_seed_preserves_branch(self) -> None:
        fundamental = validation.select_exact_seed(self.points, 0.9, "fundamental")
        third = validation.select_exact_seed(self.points, 0.9, "third")
        self.assertEqual(fundamental.step, 0)
        self.assertEqual(third.step, 5)

    def test_turning_point_requires_two_rising_points(self) -> None:
        self.assertIsNone(validation.turning_point_index(self.points[:5]))


class SolutionAndReportTests(unittest.TestCase):
    def test_checkpoint_resume_requires_a_valid_solution(self) -> None:
        manifest = validation.load_manifest()
        target = manifest["targets"][0]
        grid = next(grid for grid in target["grids"] if grid["id"] == target["production_grid"])
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            solution = root / "solution"
            pointer = root / "checkpoint.path"
            pointer.write_text(str(solution) + "\n", encoding="utf-8")
            self.assertFalse(validation.checkpoint_is_valid(pointer))
            make_solution(solution, target, grid)
            self.assertTrue(validation.checkpoint_is_valid(pointer))

    def test_wrong_third_branch_is_rejected_by_identity(self) -> None:
        manifest = validation.load_manifest()
        target = validation.target_by_id(manifest, "l1_w0900_third")
        fake = {"ell": 1, "omega": 0.9, "mass_komar": 1.1186, "minus_gtt_origin": 0.4}
        issues = validation.identity_issues(fake, target)
        self.assertIn("wrong_branch_mass", issues)
        self.assertIn("wrong_branch_central_lapse", issues)

    def test_tolerance_boundary_is_strict(self) -> None:
        manifest = validation.load_manifest()
        target = manifest["targets"][0]
        solution = {
            "issues": [], "ell": 1, "omega": target["omega"],
            "mass_komar": target["literature"]["mass"] * 1.0011,
            "angular_momentum": target["literature"]["angular_momentum"],
            "minus_gtt_origin": target["literature"]["minus_gtt_origin"],
            "mass_surface_volume_relative": 0.0,
            "angular_surface_volume_relative": 0.0,
            "j_equals_ell_q_relative": 0.0,
        }
        passed, reasons, _ = validation.evaluate_row(solution, target, manifest["acceptance"])
        self.assertFalse(passed)
        self.assertIn("mass_literature_tolerance", reasons)

    def test_report_generation_and_convergence_trends(self) -> None:
        full_manifest = validation.load_manifest()
        target = dict(full_manifest["targets"][0])
        manifest = dict(full_manifest)
        manifest["targets"] = [target]
        error_for_grid = {
            "R64_N128": 4.0e-4,
            "R64_N192": 2.0e-4,
            "R64_N256": 1.0e-4,
            "R32_N128": 4.0e-4,
            "R48_N192": 2.0e-4,
        }
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "results"
            for grid in target["grids"]:
                solution = root / "solutions" / grid["id"]
                make_solution(solution, target, grid, error_for_grid[grid["id"]])
                if grid["id"] == target["production_grid"]:
                    pointer = root / "l1" / "state" / "exact" / f"{target['id']}.path"
                else:
                    pointer = root / "l1" / "state" / "convergence" / target["id"] / f"{grid['id']}.path"
                pointer.parent.mkdir(parents=True, exist_ok=True)
                pointer.write_text(str(solution) + "\n", encoding="utf-8")
            report = validation.build_reports(manifest, root, 1)
            self.assertTrue(report["overall_pass"], report)
            output = root / "l1" / "reports"
            validation.write_reports(report, output)
            self.assertTrue((output / "validation_report.csv").exists())
            self.assertTrue(json.loads((output / "validation_report.json").read_text(encoding="utf-8"))["overall_pass"])
            self.assertIn("Overall: **PASS**", (output / "validation_report.md").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
