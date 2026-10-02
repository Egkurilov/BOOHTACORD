import unittest
from .images import web_build_arguments


class WebAudioFlagTests(unittest.TestCase):
    def test_release_can_disable_offer_with_an_explicit_build_argument(self):
        self.assertEqual(web_build_arguments({}), ['--build-arg', 'VITE_RNNOISE_ENABLED=true'])
        self.assertEqual(web_build_arguments({'VITE_RNNOISE_ENABLED': 'false'}), ['--build-arg', 'VITE_RNNOISE_ENABLED=false'])

    def test_invalid_release_flag_fails_instead_of_enabling_silently(self):
        with self.assertRaises(ValueError): web_build_arguments({'VITE_RNNOISE_ENABLED': 'yes'})
