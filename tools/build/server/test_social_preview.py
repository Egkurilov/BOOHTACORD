import unittest
from pathlib import Path
from .images import web_build_arguments


class SocialPreviewBuildArgumentsTests(unittest.TestCase):
    def test_web_image_receives_the_public_origin(self):
        args = web_build_arguments({'VITE_PUBLIC_ORIGIN': 'https://v.bootybay.ru'})
        self.assertIn('--build-arg', args)
        self.assertIn('VITE_PUBLIC_ORIGIN=https://v.bootybay.ru', args)

    def test_missing_or_non_https_origin_is_rejected(self):
        cases = ({}, {'VITE_PUBLIC_ORIGIN': 'http://v.bootybay.ru'}, {'VITE_PUBLIC_ORIGIN': 'https://v.bootybay.ru/path'}, {'VITE_PUBLIC_ORIGIN': 'https://v.bootybay.ru:0'})
        for environment in cases:
            with self.subTest(environment=environment), self.assertRaises(ValueError):
                web_build_arguments(environment)

    def test_social_route_is_public_static_and_cache_bounded(self):
        root = Path(__file__).resolve().parents[3]
        config = (root / 'clients/web/nginx.conf').read_text(encoding='utf-8')
        route = config.split('location ^~ /social/ {', 1)[1].split('location / {', 1)[0]
        self.assertIn('image/png png', route)
        self.assertIn('public, max-age=86400', route)
        self.assertIn('try_files $uri =404', route)
