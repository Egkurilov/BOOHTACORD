"""Run every project-owned Python regression under tools; reject an empty suite."""
import unittest
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[3]
    names = [".".join(path.relative_to(root).with_suffix("").parts)
             for path in sorted((root / "tools").rglob("test_*.py"))]
    if not names:
        raise RuntimeError("No tools regression tests were found")
    suite = unittest.defaultTestLoader.loadTestsFromNames(names)
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    return 0 if result.wasSuccessful() and result.testsRun > 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
