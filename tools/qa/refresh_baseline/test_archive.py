import io
import tarfile
import tempfile
import unittest
from pathlib import Path
from .run import extract


class ArchiveTests(unittest.TestCase):
    def test_rejects_escape(self):
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w') as archive:
            entry = tarfile.TarInfo('../escape')
            archive.addfile(entry)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                extract(stream.getvalue(), Path(directory))

    def test_rejects_links_outside_source(self):
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w') as archive:
            entry = tarfile.TarInfo('clients/web/link')
            entry.type, entry.linkname = tarfile.SYMTYPE, '/etc/passwd'
            archive.addfile(entry)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                extract(stream.getvalue(), Path(directory))
