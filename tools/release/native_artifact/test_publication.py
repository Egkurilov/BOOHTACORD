import unittest
from pathlib import Path


class AndroidPublicationTests(unittest.TestCase):
    def test_release_publishes_every_component_file_referenced_by_manifest(self):
        root = Path(__file__).resolve().parents[3]
        workflow = (root / '.github/workflows/android-release.yaml').read_text()
        for name in ('artifact-manifest.json', 'SHA256SUMS',
                     'LICENSE-RNNoise.txt', 'rnnoise-component.cdx.json'):
            self.assertIn('--asset "$asset_root/' + name + '"', workflow)
