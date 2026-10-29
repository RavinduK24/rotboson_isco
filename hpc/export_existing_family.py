#!/usr/bin/env python3
"""Export compact diagnostics from an existing, untouched solution family."""

import argparse
import csv
import math
from pathlib import Path


def metadata(path):
    values = {}
    with path.open() as stream:
        for line in stream:
            key, sep, value = line.rstrip().partition("=")
            if sep:
                values[key] = value
    return values


def first(path):
    with path.open() as stream:
        for line in stream:
            if line.strip() and not line.startswith("#"):
                return float(line.split()[0])
    raise ValueError("No numeric data: {}".format(path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-root", type=Path, default=Path("out"))
    parser.add_argument("--lambda", dest="paper_lambda", type=int, required=True)
    parser.add_argument("--n", type=int, default=512)
    parser.add_argument("--dr", type=float, default=0.125)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    potential = "free" if args.paper_lambda == 0 else "quartic"
    coupling = 4 * math.pi * args.paper_lambda
    rows = []
    for directory in args.out_root.glob("pot=*,l=1,w=*"):
        meta_path = directory / "run_metadata.txt"
        if not meta_path.is_file() or not (directory / "phi_max.asc").is_file():
            continue
        meta = metadata(meta_path)
        if meta.get("convergence_status") != "converged" or meta.get("potential") != potential:
            continue
        if potential != "free" and not math.isclose(float(meta.get("lambda_4", "nan")), coupling, rel_tol=1e-9):
            continue
        if int(meta.get("NrInterior", "-1")) != args.n:
            continue
        if not math.isclose(float(meta.get("dr", "nan")), args.dr, rel_tol=1e-9):
            continue
        rows.append({
            "omega": float(meta["omega"]),
            "M_Komar": float(meta["M_Komar"]),
            "J_Komar": float(meta["J_Komar"]),
            "phi_max": first(directory / "phi_max.asc"),
            "r99": first(directory / "r99.asc"),
            "GRV2": float(meta["GRV2"]),
            "GRV3": float(meta["GRV3"]),
            "profile_path": str(directory.resolve()),
        })
    rows.sort(key=lambda row: row["omega"], reverse=True)
    if not rows:
        raise SystemExit("No matching converged solutions; existing results were not changed")
    for index, row in enumerate(rows):
        row["step"] = index
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=[
            "step", "omega", "M_Komar", "J_Komar", "phi_max", "r99",
            "GRV2", "GRV3", "profile_path",
        ])
        writer.writeheader()
        writer.writerows(rows)
    print("Exported {} models to {}".format(len(rows), args.output))


if __name__ == "__main__":
    main()
