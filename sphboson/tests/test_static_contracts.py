#!/usr/bin/env python3
"""Static checks for SPHBOSON integration contracts."""
from pathlib import Path
import unittest


class StaticContractTests(unittest.TestCase):
    def test_u_seed_allocates_full_state_vector(self):
        root = Path(__file__).resolve().parents[1]
        main_c = (root / "src" / "main.c").read_text()
        initial_c = (root / "src" / "initial.c").read_text()

        self.assertIn(
            "u_seed = (double *)SAFE_MALLOC((GNUM * dim + 1) * sizeof(double));",
            main_c,
        )
        self.assertIn("memcpy(u_seed + 2 * dim", initial_c)
        self.assertIn("u_seed[w_idx] = u[w_idx];", initial_c)


if __name__ == "__main__":
    unittest.main()
