import tempfile
import unittest
from pathlib import Path

from tools.verify.toolchains.check import check_versions


class ToolchainTests(unittest.TestCase):
    def tree(self, root):
        files = {
            "clients/web/Dockerfile": "FROM node:24.18.0-alpine AS build\nCOPY public ./public\n",
            "backend/Dockerfile": "FROM golang:1.26.4-alpine AS build\n",
            "backend/go.mod": "module example\ngo 1.26.0\ntoolchain go1.26.4\n",
            ".node-version": "24.18.0\n",
            ".github/workflows/client.yaml": "flutter-version: 3.47.5\nnode-version-file: .node-version\n",
        }
        for name, content in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
        return {"node": "24.18.0", "go": "1.26.4", "flutter": "3.47.5"}

    def test_aligned_versions_are_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertEqual(check_versions(root, self.tree(root)), [])

    def test_rejects_runtime_and_ci_drift(self):
        for name, content in [
            ("clients/web/Dockerfile", "FROM node:22-alpine AS build\n"),
            (".github/workflows/client.yaml", "node-version: 22\n"),
            (".github/workflows/client.yaml", "flutter-version: 3.46.0\n"),
            ("backend/go.mod", "module example\ngo 1.26.0\n"),
        ]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                versions = self.tree(root)
                (root / name).write_text(content, encoding="utf-8")
                self.assertTrue(check_versions(root, versions))


if __name__ == "__main__":
    unittest.main()
