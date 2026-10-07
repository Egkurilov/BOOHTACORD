import unittest
from pathlib import Path
from .images import web_build_arguments


class WebAudioFlagTests(unittest.TestCase):
    def test_release_can_disable_offer_with_an_explicit_build_argument(self):
        self.assertEqual(web_build_arguments({}), ['--build-arg', 'VITE_RNNOISE_ENABLED=true'])
        self.assertEqual(web_build_arguments({'VITE_RNNOISE_ENABLED': 'false'}), ['--build-arg', 'VITE_RNNOISE_ENABLED=false'])

    def test_invalid_release_flag_fails_instead_of_enabling_silently(self):
        with self.assertRaises(ValueError): web_build_arguments({'VITE_RNNOISE_ENABLED': 'yes'})

    def test_web_dockerfile_uses_repository_root_context(self):
        root = Path(__file__).resolve().parents[3]
        source = (root / 'clients/web/Dockerfile').read_text(encoding='utf-8')
        self.assertIn('COPY clients/web/nginx.conf /etc/nginx/conf.d/default.conf', source)
        self.assertIn('COPY --from=build /app/clients/web/dist /usr/share/nginx/html', source)

    def test_web_image_includes_shared_screen_profile_catalog(self):
        root = Path(__file__).resolve().parents[3]
        source = (root / 'clients/web/Dockerfile').read_text(encoding='utf-8')
        self.assertIn(
            'COPY contracts/screen-share-profile-v1.catalog.json /app/contracts/screen-share-profile-v1.catalog.json',
            source,
        )
