"""The compact export must select only the intended coupling and grid."""

import csv
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class FamilyExportTest(unittest.TestCase):
    def test_selects_matching_models_without_touching_profiles(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "tests") as temporary:
            base = Path(temporary)
            out = base / "out"
            out.mkdir()
            for name, coupling, n in [
                ("pot=quartic,lambda_4=2.51327E+03,l=1,w=8.2E-01,dr=1.25E-01,N=0512", 2513.2741228718345, 512),
                ("pot=quartic,lambda_4=1.25664E+03,l=1,w=8.2E-01,dr=1.25E-01,N=0512", 1256.6370614359173, 512),
                ("pot=quartic,lambda_4=2.51327E+03,l=1,w=8.2E-01,dr=2.5E-01,N=0256", 2513.2741228718345, 256),
            ]:
                directory = out / name
                directory.mkdir()
                (directory / "run_metadata.txt").write_text(
                    "potential=quartic\nconvergence_status=converged\n"
                    "lambda_4={}\nNrInterior={}\ndr={}\n"
                    "omega=0.82\nM_Komar=3.48\nJ_Komar=3.71\nGRV2=0.01\nGRV3=1.2\n".format(
                        coupling, n, 0.125 if n == 512 else 0.25
                    )
                )
                (directory / "phi_max.asc").write_text("0.016\n")
                (directory / "r99.asc").write_text("18.0\n")
            destination = base / "summary.csv"
            subprocess.run([
                sys.executable, str(ROOT / "hpc" / "export_existing_family.py"),
                "--out-root", str(out), "--lambda", "200", "--output", str(destination),
            ], check=True, capture_output=True)
            with destination.open(newline="") as stream:
                rows = list(csv.DictReader(stream))
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["M_Komar"], "3.48")
            self.assertTrue(Path(rows[0]["profile_path"]).is_dir())


if __name__ == "__main__":
    unittest.main()
