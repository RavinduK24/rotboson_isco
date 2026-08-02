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

    def test_directory_names_are_checked_for_truncation(self):
        root = Path(__file__).resolve().parents[1]
        main_c = (root / "src" / "main.c").read_text()
        parser_c = (root / "src" / "parser.c").read_text()

        self.assertIn("char potential_tag[96];", main_c)
        self.assertIn("char potential_tag[96];", parser_c)
        self.assertIn("wrote < 0 || wrote >= MAX_STR_LEN", main_c)
        self.assertIn("wrote < 0 || wrote >= MAX_STR_LEN", parser_c)

    def test_csr_rejects_unsupported_order(self):
        root = Path(__file__).resolve().parents[1]
        csr_c = (root / "src" / "csr.c").read_text()
        parser_c = (root / "src" / "parser.c").read_text()

        self.assertIn("CSR: ERROR! order = %lld is not supported", csr_c)
        self.assertIn("SPHBOSON currently supports only order = 4", parser_c)


if __name__ == "__main__":
    unittest.main()
