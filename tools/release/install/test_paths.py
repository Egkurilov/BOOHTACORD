import tempfile
import unittest
from pathlib import Path
from .paths import compose_arguments, rollout_script


class RetainedPathTests(unittest.TestCase):
    def test_legacy_signed_runtime_and_canonical_layout_use_their_own_environment(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.assertEqual(compose_arguments(root), ['--project-directory', str(root), '--env-file', str(root / '.env'), '-f', str(root / 'compose.yaml')])
            self.assertEqual(rollout_script(root), root / 'scripts/deploy-images.sh')
            (root / 'deploy').mkdir()
            (root / 'deploy/compose.yaml').touch()
            self.assertEqual(compose_arguments(root), ['--project-directory', str(root / 'deploy'), '--env-file', str(root / '.env'), '-f', str(root / 'deploy/compose.yaml')])
