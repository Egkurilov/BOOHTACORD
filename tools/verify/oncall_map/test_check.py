"""The operator map must follow source drift and keep unproven gates explicit."""
import tempfile
import unittest
from pathlib import Path
from .check import DOCUMENT, validate, validate_document
from .anchors import ANCHORS, FORBIDDEN

ROOT = Path(__file__).resolve().parents[3]


class OncallMapTests(unittest.TestCase):
    def setUp(self):
        self.text = (ROOT / DOCUMENT).read_text(encoding="utf-8")

    def test_real_repository_map_and_deadlines_match(self):
        self.assertEqual(validate(ROOT), [])

    def test_missing_duplicate_or_empty_boundary_fails(self):
        row = next(line for line in self.text.splitlines() if line.startswith("| PostgreSQL |"))
        for changed in (self.text.replace(row, ""), self.text + "\n" + row,
                        self.text.replace("| PostgreSQL |", "| PostgreSQL | |")):
            with self.subTest(changed=changed[-80:]):
                self.assertTrue(validate_document(changed))

    def test_wrong_deadline_and_promoted_acceptance_fail(self):
        for changed in (self.text.replace("400 ms", "4 s"),
                        self.text.replace("POC-03: BLOCKED", "POC-03: PASS"),
                        self.text.replace("Production outage matrix: NOT_RUN", "Production outage matrix: PASS")):
            self.assertTrue(validate_document(changed))

    def test_source_drift_missing_file_and_new_implicit_timeout_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            paths = {DOCUMENT, *(path for path, _, _ in ANCHORS), *(path for path, _ in FORBIDDEN)}
            for path in paths:
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text((ROOT / path).read_text(encoding="utf-8"), encoding="utf-8")
            self.assertEqual(validate(root), [])
            path, anchor, _ = ANCHORS[0]
            source = root / path
            original = source.read_text(encoding="utf-8")
            source.write_text(original.replace(anchor, "changed"), encoding="utf-8")
            self.assertTrue(validate(root))
            source.write_text(original, encoding="utf-8")
            path, anchor = FORBIDDEN[0]
            source = root / path
            source.write_text(source.read_text(encoding="utf-8") + anchor, encoding="utf-8")
            self.assertTrue(validate(root))
            source.unlink()
            self.assertTrue(validate(root))


if __name__ == "__main__":
    unittest.main()
