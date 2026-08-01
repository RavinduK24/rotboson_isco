#!/usr/bin/env python3
import math
import sys
from pathlib import Path


REQUIRED = (
    "sph_rr.asc",
    "sph_th.asc",
    "sph_log_alpha_f.asc",
    "sph_beta_f.asc",
    "sph_log_h_f.asc",
    "sph_log_a_f.asc",
)


def read_matrix(path):
    return [[float(value) for value in line.split()] for line in path.read_text().splitlines()]


def main():
    root = Path(sys.argv[1])
    matrices = {name: read_matrix(root / name) for name in REQUIRED}
    assert all(len(matrix) == 5 for matrix in matrices.values())
    assert all(len(row) == 9 for matrix in matrices.values() for row in matrix)
    assert [row[-1] for row in matrices["sph_rr.asc"]] == [0.05, 0.15, 0.25, 0.35, 0.45]
    assert math.isclose(matrices["sph_th.asc"][0][-1], 0.5 * math.pi, abs_tol=1.0e-14)
    assert all(value == 0.0 for row in matrices["sph_beta_f.asc"] for value in row)
    assert matrices["sph_log_h_f.asc"] == matrices["sph_log_a_f.asc"]
    metadata = (root / "run_metadata.txt").read_text()
    for expected in ("solver=SPHBOSON", "potential=quartic", "l=0", "J_Komar=0."):
        assert expected in metadata
    print("ISCO export tests passed")


if __name__ == "__main__":
    main()
