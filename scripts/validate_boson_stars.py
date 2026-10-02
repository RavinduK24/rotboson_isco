#!/usr/bin/env python3
"""Branch tracking and literature validation for ROTBOSON equilibrium data."""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Optional


REPO = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = REPO / "validation" / "benchmarks.json"


def load_manifest(path: Path = DEFAULT_MANIFEST) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1 or not isinstance(data.get("targets"), list):
        raise ValueError(f"unsupported benchmark manifest: {path}")
    ids = [target["id"] for target in data["targets"]]
    if len(ids) != len(set(ids)):
        raise ValueError("benchmark target ids must be unique")
    return data


def target_by_id(manifest: dict[str, Any], target_id: str) -> dict[str, Any]:
    for target in manifest["targets"]:
        if target["id"] == target_id:
            return target
    raise KeyError(f"unknown target id: {target_id}")


def parse_metadata(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip()
    return result


def numeric_tokens(path: Path) -> Iterable[float]:
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if line.lstrip().startswith("#"):
                continue
            for token in line.split():
                try:
                    yield float(token)
                except ValueError:
                    continue


def first_numeric(path: Path) -> Optional[float]:
    return next(iter(numeric_tokens(path)), None) if path.exists() else None


def last_numeric(path: Path) -> Optional[float]:
    if not path.exists():
        return None
    value: Optional[float] = None
    for value in numeric_tokens(path):
        pass
    return value


def relative_error(value: Optional[float], reference: Optional[float]) -> Optional[float]:
    if value is None or reference is None:
        return None
    return abs(value - reference) / max(abs(reference), 1.0e-300)


def relative_difference(a: Optional[float], b: Optional[float]) -> Optional[float]:
    if a is None or b is None:
        return None
    return abs(a - b) / max(0.5 * (abs(a) + abs(b)), 1.0e-300)


def inspect_solution(directory: Path) -> dict[str, Any]:
    directory = directory.resolve()
    metadata_path = directory / "run_metadata.txt"
    if not metadata_path.exists():
        return {"path": str(directory), "valid": False, "issues": ["missing run_metadata.txt"]}
    metadata = parse_metadata(metadata_path)

    def meta_float(name: str) -> Optional[float]:
        try:
            return float(metadata[name])
        except (KeyError, ValueError):
            return None

    m_surface = last_numeric(directory / "M_Komar1.asc")
    m_volume = last_numeric(directory / "M_Komar2.asc")
    m_adm = last_numeric(directory / "M_ADM.asc")
    j_surface = last_numeric(directory / "J_Komar1.asc")
    j_volume = last_numeric(directory / "J_Komar2.asc")
    ell_value = meta_float("l")
    ell = int(ell_value) if ell_value is not None else None
    q_noether = first_numeric(directory / "Noether_charge.asc")
    if q_noether is None and j_volume is not None and ell not in (None, 0):
        q_noether = j_volume / ell
    lapse_log = first_numeric(directory / "sph_log_alpha_f.asc")
    minus_gtt_origin = math.exp(2.0 * lapse_log) if lapse_log is not None else None
    mass_average = (
        0.5 * (m_surface + m_volume)
        if m_surface is not None and m_volume is not None
        else meta_float("M_Komar")
    )
    angular_average = (
        0.5 * (j_surface + j_volume)
        if j_surface is not None and j_volume is not None
        else meta_float("J_Komar")
    )
    phi_max = first_numeric(directory / "phi_max.asc")
    issues: list[str] = []
    if metadata.get("convergence_status") != "converged":
        issues.append("solver_not_converged")
    if mass_average is None or mass_average <= 1.0e-10:
        issues.append("vacuum_or_missing_mass")
    if phi_max is None or phi_max <= 1.0e-10:
        issues.append("vacuum_or_missing_field")
    if meta_float("omega") is None:
        issues.append("missing_frequency")
    return {
        "path": str(directory),
        "valid": not issues,
        "issues": issues,
        "convergence_status": metadata.get("convergence_status", "missing"),
        "omega": meta_float("omega"),
        "ell": ell,
        "n": int(meta_float("NrInterior") or 0),
        "dr": meta_float("dr"),
        "r_max": (meta_float("dr") or 0.0) * (meta_float("NrInterior") or 0.0),
        "mass_komar": mass_average,
        "mass_komar_surface": m_surface,
        "mass_komar_volume": m_volume,
        "mass_adm": m_adm,
        "angular_momentum": angular_average,
        "angular_momentum_surface": j_surface,
        "angular_momentum_volume": j_volume,
        "noether_charge": q_noether,
        "j_equals_ell_q_relative": relative_difference(j_surface, ell * q_noether if ell and q_noether is not None else None),
        "mass_surface_volume_relative": relative_difference(m_surface, m_volume),
        "angular_surface_volume_relative": relative_difference(j_surface, j_volume),
        "minus_gtt_origin": minus_gtt_origin,
        "phi_max": phi_max,
        "rr_phi_max": first_numeric(directory / "rr_phi_max.asc"),
        "final_residual": (
            first_numeric(directory / "final_residual.asc")
            if (directory / "final_residual.asc").exists()
            else last_numeric(directory / "norm_f.asc")
        ),
        "grv2": first_numeric(directory / "GRV2.asc") if (directory / "GRV2.asc").exists() else meta_float("GRV2"),
        "grv3": first_numeric(directory / "GRV3.asc") if (directory / "GRV3.asc").exists() else meta_float("GRV3"),
    }


@dataclass(frozen=True)
class BranchPoint:
    step: int
    path: Path
    omega: float
    mass: float
    phi_max: float
    amplitude_increment: float


def read_branch_index(path: Path) -> list[BranchPoint]:
    if not path.exists():
        return []
    points: list[BranchPoint] = []
    with path.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            points.append(BranchPoint(
                int(row["step"]), Path(row["path"]), float(row["omega"]),
                float(row["mass"]), float(row["phi_max"]),
                float(row["amplitude_increment"]),
            ))
    return sorted(points, key=lambda point: point.step)


def turning_point_index(points: list[BranchPoint]) -> Optional[int]:
    if len(points) < 5:
        return None
    candidate = min(range(len(points)), key=lambda index: points[index].omega)
    if candidate < 2 or candidate + 2 >= len(points):
        return None
    before = [point.omega for point in points[candidate - 2:candidate + 1]]
    after = [point.omega for point in points[candidate:candidate + 3]]
    if before[0] > before[1] > before[2] and after[0] < after[1] < after[2]:
        return candidate
    return None


def branch_candidates(points: list[BranchPoint], branch: str) -> list[BranchPoint]:
    turning = turning_point_index(points)
    if branch == "fundamental":
        return points if turning is None else points[:turning + 1]
    if branch == "third":
        if turning is None:
            return []
        return points[turning + 1:]
    raise ValueError(f"unsupported branch: {branch}")


def select_exact_seed(points: list[BranchPoint], omega: float, branch: str) -> BranchPoint:
    candidates = branch_candidates(points, branch)
    if not candidates:
        raise ValueError(f"no {branch} branch seed is available")
    return min(candidates, key=lambda point: abs(point.omega - omega))


def brackets_frequency(points: list[BranchPoint], omega: float, branch: str) -> bool:
    values = [point.omega for point in branch_candidates(points, branch)]
    return bool(values) and min(values) <= omega <= max(values)


def branch_phase_ready(points: list[BranchPoint], phase: str, target_omegas: Optional[list[float]] = None) -> bool:
    omegas = ([0.8, 0.9] if phase == "fundamental" else [0.9]) if target_omegas is None else target_omegas
    if not omegas:
        return True
    if phase == "fundamental":
        return bool(omegas) and all(brackets_frequency(points, omega, "fundamental") for omega in omegas)
    if phase == "third":
        turning = turning_point_index(points)
        if turning is None:
            return False
        rising = [point.omega for point in points[turning + 1:]]
        return bool(omegas) and bool(rising) and all(min(rising) < omega < max(rising) for omega in omegas)
    raise ValueError(f"unsupported phase: {phase}")


def pointer_solution(pointer: Path) -> Optional[Path]:
    if not pointer.exists():
        return None
    value = pointer.read_text(encoding="utf-8").splitlines()[0].strip()
    if not value:
        return None
    path = Path(value)
    return path if path.is_absolute() else (pointer.parent / path).resolve()


def checkpoint_is_valid(pointer: Path) -> bool:
    solution = pointer_solution(pointer)
    return solution is not None and bool(inspect_solution(solution)["valid"])


def identity_issues(solution: dict[str, Any], target: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    if solution.get("ell") != target["ell"]:
        issues.append("wrong_ell")
    if abs((solution.get("omega") or 0.0) - target["omega"]) > 1.0e-10:
        issues.append("wrong_frequency")
    window = target.get("identity_window", {})
    if "mass_relative" in window:
        error = relative_error(solution.get("mass_komar"), target["literature"].get("mass"))
        if error is None or error > window["mass_relative"]:
            issues.append("wrong_branch_mass")
    if "mass_absolute" in window:
        if abs((solution.get("mass_komar") or 0.0) - target["literature"]["mass"]) > window["mass_absolute"]:
            issues.append("wrong_branch_mass")
    if "minus_gtt_origin_max" in window:
        value = solution.get("minus_gtt_origin")
        if value is None or value > window["minus_gtt_origin_max"]:
            issues.append("wrong_branch_central_lapse")
    if "minus_gtt_origin_relative" in window:
        error = relative_error(solution.get("minus_gtt_origin"), target["literature"].get("minus_gtt_origin"))
        if error is None or error > window["minus_gtt_origin_relative"]:
            issues.append("wrong_branch_central_lapse")
    return issues


def evaluate_row(solution: dict[str, Any], target: dict[str, Any], acceptance: dict[str, float]) -> tuple[bool, list[str], dict[str, Optional[float]]]:
    reasons = list(solution.get("issues", []))
    literature = target["literature"]
    errors = {
        "mass_relative_error": relative_error(solution.get("mass_komar"), literature.get("mass")),
        "angular_momentum_relative_error": relative_error(solution.get("angular_momentum"), literature.get("angular_momentum")),
        "minus_gtt_origin_relative_error": relative_error(solution.get("minus_gtt_origin"), literature.get("minus_gtt_origin")),
    }
    omega = solution.get("omega")
    if omega is None or abs(omega - target["omega"]) > acceptance["omega_absolute"]:
        reasons.append("frequency_tolerance")
    for field, error_name in (("mass", "mass_relative_error"), ("angular_momentum", "angular_momentum_relative_error")):
        if field in target.get("strict", []) and (errors[error_name] is None or errors[error_name] >= acceptance["strict_relative"]):
            reasons.append(f"{field}_literature_tolerance")
        if field in target.get("rounded", []) and (errors[error_name] is None or errors[error_name] >= acceptance["rounded_relative"]):
            reasons.append(f"{field}_rounded_literature_tolerance")
    if "minus_gtt_origin" in target.get("strict", []):
        error = errors["minus_gtt_origin_relative_error"]
        absolute = None
        if solution.get("minus_gtt_origin") is not None and literature.get("minus_gtt_origin") is not None:
            absolute = abs(solution["minus_gtt_origin"] - literature["minus_gtt_origin"])
        if target["branch"] == "third":
            if (error is None or error >= acceptance["central_lapse_relative"]) and (absolute is None or absolute >= acceptance["central_lapse_absolute"]):
                reasons.append("central_lapse_tolerance")
        elif error is None or error >= acceptance["strict_relative"]:
            reasons.append("central_lapse_literature_tolerance")
    for key in ("mass_surface_volume_relative", "angular_surface_volume_relative"):
        value = solution.get(key)
        if value is None or value >= acceptance["surface_volume_relative"]:
            reasons.append(key)
    jq = solution.get("j_equals_ell_q_relative")
    if jq is None or jq >= acceptance["j_equals_ell_q_relative"]:
        reasons.append("j_equals_ell_q_tolerance")
    reasons.extend(identity_issues(solution, target))
    return not reasons, sorted(set(reasons)), errors


def _trend_pass(rows: list[dict[str, Any]], target: dict[str, Any], series: str) -> tuple[bool, str]:
    selected = []
    for row in rows:
        grid = next(grid for grid in target["grids"] if grid["id"] == row["grid_id"])
        if series in grid["series"].split(","):
            selected.append((grid, row))
    key = "n" if series == "resolution" else "r_max"
    selected.sort(key=lambda item: item[0][key])
    if len(selected) < 3:
        return False, f"{series}_series_incomplete"
    previous, finest = selected[-2][1], selected[-1][1]
    for observable in ("mass_relative_error", "angular_momentum_relative_error"):
        if observable not in finest or finest[observable] is None:
            continue
        if previous.get(observable) is None or finest[observable] > previous[observable] + 1.0e-12:
            return False, f"{series}_{observable}_worsened"
    return True, "pass"


def build_reports(manifest: dict[str, Any], root: Path, ell: int) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    summaries: list[dict[str, Any]] = []
    acceptance = manifest["acceptance"]
    for target in [item for item in manifest["targets"] if item["ell"] == ell]:
        target_rows: list[dict[str, Any]] = []
        for grid in target["grids"]:
            if grid["id"] == target["production_grid"]:
                pointer = root / f"l{ell}" / "state" / "exact" / f"{target['id']}.path"
            else:
                pointer = root / f"l{ell}" / "state" / "convergence" / target["id"] / f"{grid['id']}.path"
            solution_path = pointer_solution(pointer)
            solution = inspect_solution(solution_path) if solution_path else {
                "path": "", "valid": False, "issues": ["missing_checkpoint"]
            }
            passed, reasons, errors = evaluate_row(solution, target, acceptance)
            row = {
                "target_id": target["id"], "branch": target["branch"],
                "branch_identity": f"{target['branch']} (seed-locked)",
                "target_omega": target["omega"],
                "grid_id": grid["id"], "series": grid["series"],
                "expected_n": grid["n"], "expected_r_max": grid["r_max"],
                "is_production": grid["id"] == target["production_grid"],
                **solution, **errors, "row_pass": passed,
                "reasons": ";".join(reasons) if reasons else "pass",
            }
            rows.append(row)
            target_rows.append(row)
        production = next(row for row in target_rows if row["is_production"])
        resolution_pass, resolution_reason = _trend_pass(target_rows, target, "resolution")
        boundary_pass, boundary_reason = _trend_pass(target_rows, target, "boundary")
        reasons = [] if production["row_pass"] else production["reasons"].split(";")
        if not resolution_pass:
            reasons.append(resolution_reason)
        if not boundary_pass:
            reasons.append(boundary_reason)
        summaries.append({
            "target_id": target["id"], "branch": target["branch"],
            "pass": not reasons, "reasons": sorted(set(reasons)) or ["pass"],
            "resolution_trend_pass": resolution_pass,
            "boundary_trend_pass": boundary_pass,
            "source": target["source"],
            "precision_note": target.get("precision", "strict benchmark"),
        })
    return {
        "schema_version": 1,
        "ell": ell,
        "overall_pass": bool(summaries) and all(item["pass"] for item in summaries),
        "targets": summaries,
        "rows": rows,
    }


def write_reports(report: dict[str, Any], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "validation_report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    csv_path = output_dir / "validation_report.csv"
    fieldnames = sorted({key for row in report["rows"] for key in row if not isinstance(row[key], (list, dict))})
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows({key: row.get(key, "") for key in fieldnames} for row in report["rows"])
    lines = [
        "# Boson-star literature validation", "",
        f"Overall: **{'PASS' if report['overall_pass'] else 'FAIL'}**", "",
        "| Target | Branch | Result | Resolution trend | Boundary trend | Reasons |",
        "|---|---|---:|---:|---:|---|",
    ]
    for target in report["targets"]:
        lines.append(
            f"| `{target['target_id']}` | {target['branch']} | "
            f"{'PASS' if target['pass'] else 'FAIL'} | "
            f"{'PASS' if target['resolution_trend_pass'] else 'FAIL'} | "
            f"{'PASS' if target['boundary_trend_pass'] else 'FAIL'} | "
            f"{', '.join(target['reasons'])} |"
        )
    lines.extend(["", "## Grid observables", "",
        "| Target | Grid | Branch identity | target omega | achieved omega | M ADM | M K surf | M K vol | M K avg | J K surf | J K vol | J K avg | Q | -gtt(0) | phi max | residual | GRV2 | GRV3 |",
        "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ])
    def fmt(value: Any) -> str:
        return "--" if value is None or value == "" else f"{value:.8e}" if isinstance(value, float) else str(value)
    for row in report["rows"]:
        lines.append(
            f"| `{row['target_id']}` | `{row['grid_id']}` | {row['branch_identity']} | "
            f"{fmt(row.get('target_omega'))} | {fmt(row.get('omega'))} | {fmt(row.get('mass_adm'))} | "
            f"{fmt(row.get('mass_komar_surface'))} | {fmt(row.get('mass_komar_volume'))} | {fmt(row.get('mass_komar'))} | "
            f"{fmt(row.get('angular_momentum_surface'))} | {fmt(row.get('angular_momentum_volume'))} | "
            f"{fmt(row.get('angular_momentum'))} | {fmt(row.get('noether_charge'))} | "
            f"{fmt(row.get('minus_gtt_origin'))} | {fmt(row.get('phi_max'))} | {fmt(row.get('final_residual'))} | "
            f"{fmt(row.get('grv2'))} | {fmt(row.get('grv3'))} |"
        )
    lines.extend(["", "## Errors and consistency", "",
        "| Target | Grid | dM/M | dJ/J | d[-gtt(0)] | M surface/volume | J surface/volume | J=ell Q | Result/reasons |",
        "|---|---|---:|---:|---:|---:|---:|---:|---|",
    ])
    for row in report["rows"]:
        lines.append(
            f"| `{row['target_id']}` | `{row['grid_id']}` | {fmt(row.get('mass_relative_error'))} | "
            f"{fmt(row.get('angular_momentum_relative_error'))} | {fmt(row.get('minus_gtt_origin_relative_error'))} | "
            f"{fmt(row.get('mass_surface_volume_relative'))} | {fmt(row.get('angular_surface_volume_relative'))} | "
            f"{fmt(row.get('j_equals_ell_q_relative'))} | {'PASS' if row['row_pass'] else row['reasons']} |"
        )
    (output_dir / "validation_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def cli() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    subparsers = parser.add_subparsers(dest="command", required=True)
    summary_parser = subparsers.add_parser("manifest-summary")
    summary_parser.add_argument("--ell", type=int, required=True)
    targets_parser = subparsers.add_parser("targets")
    targets_parser.add_argument("--ell", type=int, required=True)
    matrix_parser = subparsers.add_parser("matrix")
    matrix_parser.add_argument("--ell", type=int, required=True)
    matrix_parser.add_argument("--exclude-production", action="store_true")
    profile_parser = subparsers.add_parser("profile")
    profile_parser.add_argument("--ell", type=int, required=True)
    seed_parser = subparsers.add_parser("select-seed")
    seed_parser.add_argument("--index", type=Path, required=True)
    seed_parser.add_argument("--omega", type=float, required=True)
    seed_parser.add_argument("--branch", choices=("fundamental", "third"), required=True)
    ready_parser = subparsers.add_parser("branch-ready")
    ready_parser.add_argument("--index", type=Path, required=True)
    ready_parser.add_argument("--phase", choices=("fundamental", "third"), required=True)
    ready_parser.add_argument("--ell", type=int, required=True)
    check_parser = subparsers.add_parser("check-solution")
    check_parser.add_argument("--path", type=Path, required=True)
    check_parser.add_argument("--target-id")
    report_parser = subparsers.add_parser("report")
    report_parser.add_argument("--root", type=Path, required=True)
    report_parser.add_argument("--ell", type=int, required=True)
    report_parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = load_manifest(args.manifest)
    if args.command == "manifest-summary":
        targets = [target for target in manifest["targets"] if target["ell"] == args.ell]
        sequences = [target for target in manifest.get("sequence_targets", []) if target["ell"] == args.ell]
        print(f"ell={args.ell} solver={manifest['solvers']['sphboson' if args.ell == 0 else 'rotboson']['path']}")
        for target in targets:
            print(f"  {target['id']}: omega={target['omega']} branch={target['branch']} grids={len(target['grids'])}")
        for target in sequences:
            print(f"  {target['id']}: optional sequence benchmark {target['literature']}")
    elif args.command == "targets":
        for target in manifest["targets"]:
            if target["ell"] == args.ell:
                grid = next(grid for grid in target["grids"] if grid["id"] == target["production_grid"])
                print(f"{target['id']}\t{target['omega']:.17g}\t{target['branch']}\t{grid['n']}\t{grid['r_max']:.17g}\t{grid['id']}")
    elif args.command == "matrix":
        for target in manifest["targets"]:
            if target["ell"] != args.ell:
                continue
            for grid in target["grids"]:
                if args.exclude_production and grid["id"] == target["production_grid"]:
                    continue
                print(f"{target['id']}\t{grid['id']}\t{grid['n']}\t{grid['r_max']:.17g}\t{target['omega']:.17g}\t{target['branch']}")
    elif args.command == "profile":
        profile = next((item for item in manifest.get("continuation_profiles", []) if item["ell"] == args.ell), None)
        if profile is None:
            raise ValueError(f"no continuation profile is registered for ell={args.ell}")
        print(
            f"{profile['n']}\t{profile['r_max']:.17g}\t{profile['seed_omega']:.17g}\t"
            f"{profile['seed_psi0']:.17g}\t{profile['initial_amplitude_increment']:.17g}\t"
            f"{profile['minimum_amplitude_increment']:.17g}"
        )
    elif args.command == "select-seed":
        print(select_exact_seed(read_branch_index(args.index), args.omega, args.branch).path)
    elif args.command == "branch-ready":
        omegas = [
            target["omega"] for target in manifest["targets"]
            if target["ell"] == args.ell and target["branch"] == args.phase
        ]
        ready = branch_phase_ready(read_branch_index(args.index), args.phase, omegas)
        print("ready" if ready else "incomplete")
        return 0 if ready else 1
    elif args.command == "check-solution":
        solution = inspect_solution(args.path)
        issues = list(solution.get("issues", []))
        if args.target_id:
            issues.extend(identity_issues(solution, target_by_id(manifest, args.target_id)))
        print(json.dumps({**solution, "issues": sorted(set(issues)), "valid": not issues}, sort_keys=True))
        return 0 if not issues else 1
    elif args.command == "report":
        report = build_reports(manifest, args.root.resolve(), args.ell)
        write_reports(report, args.output_dir.resolve())
        print(args.output_dir.resolve() / "validation_report.md")
        return 0 if report["overall_pass"] else 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(cli())
    except (KeyError, ValueError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
