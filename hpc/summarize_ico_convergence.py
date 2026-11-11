#!/usr/bin/env python3
"""Write a compact co-rotating ICO central-refinement summary."""

import argparse
import csv
import math
import re
from pathlib import Path


GRID_RE = re.compile(r"dr=(?P<dr>[0-9.Ee+-]+),N=(?P<n>\d+)")


def number(row, key):
    try:
        return float(row[key])
    except (KeyError, TypeError, ValueError):
        return math.nan


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    with args.summary.open(newline="", encoding="utf-8") as handle:
        rows = [row for row in csv.DictReader(handle) if row.get("orbital_branch") == "co"]

    output_rows = []
    for row in rows:
        match = GRID_RE.search(row["directory"])
        if not match:
            continue
        output_rows.append({
            "N": int(match.group("n")),
            "dr": float(match.group("dr")),
            "omega": number(row, "omega_star"),
            "mass": number(row, "mass"),
            "r_ico": number(row, "isco_std_coordinate_radius"),
            "R_ico": number(row, "isco_std_circumferential_radius"),
            "R_ico_over_M": number(row, "isco_std_circumferential_radius_over_M"),
            "uncertainty": number(row, "isco_std_numerical_uncertainty"),
            "selection_kind": row.get("isco_std_selection_kind", ""),
            "topology": row.get("stability_topology", ""),
            "status": row.get("status", ""),
            "directory": row["directory"],
        })
    output_rows.sort(key=lambda row: row["dr"], reverse=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fields = list(output_rows[0]) if output_rows else ["N", "dr", "status"]
    with args.output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(output_rows)

    markdown = args.output.with_suffix(".md")
    with markdown.open("w", encoding="utf-8") as handle:
        handle.write("# Co-rotating ICO central-grid convergence\n\n")
        handle.write("| N | dr | omega | M | r_ICO | R_ICO/M | uncertainty | selection | topology |\n")
        handle.write("|---:|---:|---:|---:|---:|---:|---:|---|---|\n")
        for row in output_rows:
            handle.write(
                "| {N} | {dr:.8g} | {omega:.10g} | {mass:.10g} | {r_ico:.10g} | "
                "{R_ico_over_M:.10g} | {uncertainty:.4g} | {selection_kind} | {topology} |\n".format(**row)
            )
        handle.write("\nA physical ICO should approach a nonzero coordinate and circumferential radius as dr decreases.\n")


if __name__ == "__main__":
    main()
