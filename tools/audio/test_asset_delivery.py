import unittest
from pathlib import Path


class AssetDeliveryTests(unittest.TestCase):
    def test_versioned_audio_assets_never_use_spa_fallback(self):
        config = Path('clients/web/nginx.conf').read_text()
        self.assertIn('location ^~ /audio/rnnoise/', config)
        audio = config.split('location ^~ /audio/rnnoise/', 1)[1].split('location / {', 1)[0]
        self.assertIn('try_files $uri =404;', audio)
        self.assertNotIn('/index.html', audio)
