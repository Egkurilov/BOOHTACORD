import tempfile
import unittest
from pathlib import Path
from .runtime import check_expanded, prepare_environment


class RetainedRuntimeTests(unittest.TestCase):
    def test_changed_or_missing_expanded_script_blocks_reuse(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            signed, retained = root / 'signed', root / 'retained'
            signed.mkdir(); retained.mkdir()
            (signed / 'install.sh').write_text('trusted')
            with self.assertRaises(ValueError): check_expanded(retained, signed)
            (retained / 'install.sh').write_text('trusted')
            check_expanded(retained, signed)
            (retained / 'install.sh').write_text('changed')
            with self.assertRaises(ValueError): check_expanded(retained, signed)

    def test_host_environment_is_copied_without_changing_its_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            host = root / 'host.env'; host.write_text('PUBLIC_HOST=localhost\n')
            release = root / 'release'; release.mkdir()
            prepare_environment(release, host)
            self.assertEqual((release / '.env').read_bytes(), host.read_bytes())
