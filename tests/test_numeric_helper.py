import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "hpc" / "numeric_helper.py"


class NumericHelperTests(unittest.TestCase):
    def run_helper(self, *args):
        return subprocess.run(
            [sys.executable, str(HELPER)] + list(args),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )

    def test_last_returns_last_numeric_row(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "series.asc"
            path.write_text("# radius value\n1.0\n2.5\n", encoding="utf-8")
            result = self.run_helper("last", str(path))
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "2.5")

    def test_equilibrium_quality_checks_boundary_margin(self):
        accepted = self.run_helper(
            "equilibrium-quality",
            "3.48", "3.47", "3.70", "3.46", "0.01", "0.05", "30", "64",
            "0.02", "0.05", "0.8",
        )
        rejected = self.run_helper(
            "equilibrium-quality",
            "3.48", "3.47", "3.70", "3.46", "0.01", "0.05", "63", "64",
            "0.02", "0.05", "0.8",
        )
        self.assertEqual(accepted.returncode, 0)
        self.assertNotEqual(rejected.returncode, 0)

    def test_equilibrium_quality_uses_asymptotic_mass_not_finite_adm(self):
        accepted = self.run_helper(
            "equilibrium-quality",
            "2.59189306", "2.59189308", "2.75250602", "2.59255",
            "-0.0003", "2.11", "28.99", "64",
            "0.02", "0.05", "0.8",
        )
        rejected = self.run_helper(
            "equilibrium-quality",
            "2.59189306", "2.59189308", "2.75250602", "2.80",
            "-0.0003", "2.11", "28.99", "64",
            "0.02", "0.05", "0.8",
        )
        self.assertEqual(accepted.returncode, 0)
        self.assertNotEqual(rejected.returncode, 0)


if __name__ == "__main__":
    unittest.main()
