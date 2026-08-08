"""Summarize and plot ROTBOSON output directories.

Run this from the ROTBOSON directory after the executable has generated
solution directories under out/.
"""
import argparse
import csv
import math
import re
from pathlib import Path
from typing import Any, Dict, List, Optional


OUTPUT_RE = re.compile(
    r"l=(?P<ell>\d+),w=(?P<omega>[0-9.Ee+-]+),dr=(?P<dr>[0-9.Ee+-]+),N=(?P<n>\d+)"
)


def read_last_value(path: Path) -> float:
    values = read_values(path)
    return values[-1]


def read_first_value(path: Path) -> float:
    values = read_values(path)
    return values[0]


def read_values(path: Path) -> List[float]:
    values = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            values.extend(float(part) for part in line.split())
    if not values:
        raise ValueError(f"No numeric values found in {path}")
    return values


def read_metadata(path: Path) -> Dict[str, str]:
    metadata = {}
    if not path.exists():
        return metadata
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            metadata[key.strip()] = value.strip()
    return metadata


def solution_rows(out_dir: Path) -> List[Dict[str, Any]]:
    rows = []
    for child in sorted(out_dir.iterdir()):
        if not child.is_dir():
            continue
        match = OUTPUT_RE.search(child.name)
        if not match:
            continue

        metadata = read_metadata(child / "run_metadata.txt")

        required = [
            "w_f.asc",
            "M_Komar1.asc",
            "M_Komar2.asc",
            "J_Komar1.asc",
            "J_Komar2.asc",
            "M_ADM.asc",
            "GRV2.asc",
            "GRV3.asc",
            "r99.asc",
            "phi_max.asc",
            "rr_phi_max.asc",
        ]
        missing = [name for name in required if not (child / name).exists()]
        if missing:
            print(f"Skipping {child.name}: missing {', '.join(missing)}")
            continue

        ell = int(metadata.get("l", match.group("ell")))
        omega = read_first_value(child / "w_f.asc")
        m_komar_surface = read_last_value(child / "M_Komar1.asc")
        m_komar_volume = read_last_value(child / "M_Komar2.asc")
        j_komar_surface = read_last_value(child / "J_Komar1.asc")
        j_komar_volume = read_last_value(child / "J_Komar2.asc")
        mass = 0.5 * (m_komar_surface + m_komar_volume)
        angular_momentum = 0.5 * (j_komar_surface + j_komar_volume)
        particle_number = j_komar_volume / ell if ell else math.nan

        rows.append(
            {
                "directory": child.name,
                "potential": metadata.get("potential", "free"),
                "coupling_name": metadata.get("coupling_name", "none"),
                "coupling_value": float(metadata.get("coupling_value", "0")),
                "convergence_status": metadata.get("convergence_status", "legacy_unknown"),
                "ell": ell,
                "omega": omega,
                "mass": mass,
                "M_ADM": read_last_value(child / "M_ADM.asc"),
                "M_Komar_surface": m_komar_surface,
                "M_Komar_volume": m_komar_volume,
                "J": angular_momentum,
                "J_Komar_surface": j_komar_surface,
                "J_Komar_volume": j_komar_volume,
                "particle_number": particle_number,
                "binding_energy": mass - particle_number,
                "r99": read_first_value(child / "r99.asc"),
                "GRV2": read_first_value(child / "GRV2.asc"),
                "GRV3": read_first_value(child / "GRV3.asc"),
                "phi_max": read_first_value(child / "phi_max.asc"),
                "rr_phi_max": read_first_value(child / "rr_phi_max.asc"),
            }
        )

    return sorted(rows, key=lambda row: (row["potential"], -row["omega"]))


def write_summary(rows: List[Dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0].keys())
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def load_reference(path: Optional[Path]) -> Optional[Dict[str, List[float]]]:
    if path is None:
        return None
    with path.open(newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None:
            return None
        columns = {name: [] for name in reader.fieldnames}
        for row in reader:
            for name in columns:
                value = row.get(name, "")
                if value:
                    columns[name].append(float(value))
    return columns


def plot_quantity(
    rows: list[dict[str, Any]],
    x_name: str,
    y_name: str,
    ylabel: str,
    path: Path,
    reference: Optional[Dict[str, List[float]]],
) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(6.5, 4.5))
    potentials = sorted({row["potential"] for row in rows})
    for potential in potentials:
        group = sorted((row for row in rows if row["potential"] == potential), key=lambda row: row[x_name])
        ax.plot([row[x_name] for row in group], [row[y_name] for row in group], "o-", label=potential)
    if reference and x_name in reference and y_name in reference:
        ax.plot(reference[x_name], reference[y_name], "s", mfc="none", label="paper/reference")
    ax.set_xlabel(x_name)
    ax.set_ylabel(ylabel)
    ax.grid(alpha=0.3)
    ax.legend()
    fig.tight_layout()
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(path, dpi=180)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("out"),
        help="Directory containing ROTBOSON solution folders.",
    )
    parser.add_argument(
        "--plot-dir",
        type=Path,
        default=Path("results/rotboson"),
        help="Directory for summary CSV and plots.",
    )
    parser.add_argument(
        "--reference-csv",
        type=Path,
        default=None,
        help="Optional digitized paper data with columns like omega,mass,J,particle_number,r99.",
    )
    args = parser.parse_args()

    rows = solution_rows(args.out_dir)
    if not rows:
        raise SystemExit(f"No complete ROTBOSON solution directories found in {args.out_dir}")

    summary_path = args.plot_dir / "rotboson_summary.csv"
    write_summary(rows, summary_path)
    reference = load_reference(args.reference_csv)

    try:
        import matplotlib.pyplot  # noqa: F401
    except ModuleNotFoundError:
        print(f"Wrote {summary_path}")
        print("Install matplotlib to generate plots: python -m pip install matplotlib")
        return

    plot_quantity(rows, "omega", "mass", "M", args.plot_dir / "mass_vs_omega.png", reference)
    plot_quantity(rows, "omega", "J", "J", args.plot_dir / "angular_momentum_vs_omega.png", reference)
    plot_quantity(
        rows,
        "omega",
        "particle_number",
        "N",
        args.plot_dir / "particle_number_vs_omega.png",
        reference,
    )
    plot_quantity(rows, "omega", "r99", "r99", args.plot_dir / "r99_vs_omega.png", reference)
    plot_quantity(rows, "r99", "mass", "M", args.plot_dir / "mass_vs_r99.png", reference)
    plot_quantity(rows, "mass", "J", "J", args.plot_dir / "angular_momentum_vs_mass.png", reference)

    print(f"Wrote {summary_path}")
    print(f"Wrote plots to {args.plot_dir}")


if __name__ == "__main__":
    main()
