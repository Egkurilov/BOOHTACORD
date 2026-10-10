import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.verify import uiux_visual_matrix


class UiuxVisualMatrixTest(unittest.TestCase):
    def test_missing_local_archive_reports_not_run_after_catalog_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            screens = []
            for index in range(41):
                fixture = f"fixtures/{index}.html"
                web_test = f"tests/web/{index}.spec.ts"
                flutter_test = f"tests/flutter/{index}_test.dart"
                for relative in (fixture, web_test, flutter_test):
                    path = root / relative
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text("test", encoding="utf-8")
                screens.append({
                    "id": f"S{index:02d}",
                    "surface": "desktop" if index < 18 else "mobile",
                    "referenceAsset": f"screen-{index:02d}.png",
                    "fixture": fixture,
                    "testFile": web_test,
                    "flutterTestFile": flutter_test,
                    "interaction": "navigate",
                    "expectedOrException": "preserve selection",
                    "owner": "client",
                })

            matrix_path = root / "matrix.json"
            matrix_path.write_text(json.dumps({
                "expectedCount": 41,
                "sourceArchive": "missing-audit-archive.zip",
                "screens": screens,
            }), encoding="utf-8")

            output = io.StringIO()
            with patch.object(uiux_visual_matrix, "ROOT", root), \
                    patch.object(uiux_visual_matrix, "MATRIX_PATH", matrix_path), \
                    contextlib.redirect_stdout(output):
                result = uiux_visual_matrix.main()

            self.assertEqual(result, 0)
            self.assertIn("NOT_RUN: source archive is not present", output.getvalue())
            self.assertNotIn("PASS:", output.getvalue())


if __name__ == "__main__":
    unittest.main()
