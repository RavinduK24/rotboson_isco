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

    def test_newton_history_allocates_max_iteration_slot(self):
        root = Path(__file__).resolve().parents[1]
        main_c = (root / "src" / "main.c").read_text()

        self.assertIn("for (i = 0; i <= maxNewtonIter; i++)", main_c)
        self.assertNotIn("for (i = 0; i < maxNewtonIter; i++)", main_c)

    def test_low_rank_path_is_disabled(self):
        root = Path(__file__).resolve().parents[1]
        main_c = (root / "src" / "main.c").read_text()
        template = (root / "out" / "l0_production.par").read_text()

        self.assertIn("useLowRank=1 is not supported", main_c)
        self.assertIn("linear_solve_1 = pardiso_simple_solve;", main_c)
        self.assertIn("useLowRank = 0", template)

    def test_directory_names_are_checked_for_truncation(self):
        root = Path(__file__).resolve().parents[1]
        main_c = (root / "src" / "main.c").read_text()
        parser_c = (root / "src" / "parser.c").read_text()

        self.assertIn("char potential_tag[96];", main_c)
        self.assertIn("char potential_tag[96];", parser_c)
        self.assertIn("wrote < 0 || wrote >= MAX_STR_LEN", main_c)
        self.assertIn("wrote < 0 || wrote >= MAX_STR_LEN", parser_c)

    def test_output_directory_names_are_unique(self):
        root = Path(__file__).resolve().parents[1]
        main_c = (root / "src" / "main.c").read_text()

        self.assertIn("static void make_unique_output_name", main_c)
        self.assertIn("static void reset_initial_output_name", main_c)
        self.assertIn('",phi=X.XXXXXE+00,w=X.XXXXXE-01%s"', main_c)
        self.assertIn('strstr(grid_tail, ",run=")', main_c)
        self.assertIn('"%s,run=%03d"', main_c)
        self.assertEqual(main_c.count("make_unique_output_name("), 4)

    def test_isco_export_metadata_includes_phi_max(self):
        root = Path(__file__).resolve().parents[1]
        export_c = (root / "src" / "isco_export.c").read_text()
        export_h = (root / "src" / "isco_export.h").read_text()
        test_c = (root / "tests" / "test_isco_export.c").read_text()

        self.assertIn('fprintf(file, "phi_max=%.17E\\n", phi_max);', export_c)
        self.assertIn("double M_Komar, double M_ADM, double phi_max", export_c)
        self.assertIn("double M_Komar, double M_ADM, double phi_max", export_h)
        self.assertIn("0.61, 0.60, 0.25, 0", test_c)

    def test_csr_rejects_unsupported_order(self):
        root = Path(__file__).resolve().parents[1]
        csr_c = (root / "src" / "csr.c").read_text()
        parser_c = (root / "src" / "parser.c").read_text()

        self.assertIn("CSR: ERROR! order = %lld is not supported", csr_c)
        self.assertIn("SPHBOSON currently supports only order = 4", parser_c)


if __name__ == "__main__":
    unittest.main()
