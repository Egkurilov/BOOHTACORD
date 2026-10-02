import json
import tempfile
import unittest
from pathlib import Path
from tools.release.native_artifact.audio_component import write_audio_component


class NativeAudioComponentTests(unittest.TestCase):
    def test_release_sidecars_bind_exact_pinned_source_and_model(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = write_audio_component(Path(temporary))
            sbom = json.loads((Path(temporary) / 'rnnoise-component.cdx.json').read_text())
            self.assertEqual(sbom['bomFormat'], 'CycloneDX')
            self.assertEqual(result['source_commit'], 'cdf196b1e9de2f8ff1003328ebf9a4316477429d')
            self.assertEqual(result['model_sha256'], 'f0cdb52b30501aab489f90fedbc7a023c719d91b337db2da7f26fc3036556b95')
            self.assertIn('Redistribution', (Path(temporary) / 'LICENSE-RNNoise.txt').read_text())
