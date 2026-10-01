import io
import tarfile
import tempfile
import unittest
from pathlib import Path
from .extract import extract


class ExtractTests(unittest.TestCase):
    def test_rejects_paths_links_duplicates_and_expansion_limit(self):
        for name, kind, limit in (("../escape", "file", 10), ("/absolute", "file", 10),
                                  ("link", "link", 10), ("file", "duplicate", 10), ("file", "file", 1)):
            with self.subTest(name=name, kind=kind), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                archive = root / "payload.tar"
                with tarfile.open(archive, "w") as stream:
                    entry = tarfile.TarInfo(name)
                    if kind == "link":
                        entry.type, entry.linkname = tarfile.SYMTYPE, "/etc/passwd"
                        stream.addfile(entry)
                    else:
                        entry.size = 4
                        stream.addfile(entry, io.BytesIO(b"data"))
                        if kind == "duplicate": stream.addfile(entry, io.BytesIO(b"data"))
                with self.assertRaises(ValueError): extract(archive, root / "out", max_bytes=limit)

    def test_extracts_regular_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "payload.tar"
            with tarfile.open(archive, "w") as stream:
                entry = tarfile.TarInfo("nested/data")
                entry.size = 4
                stream.addfile(entry, io.BytesIO(b"data"))
            extract(archive, root / "out", max_bytes=10)
            self.assertEqual((root / "out/nested/data").read_bytes(), b"data")


if __name__ == "__main__": unittest.main()
