import unittest

from tools.build.web.assets import verify_png


class PublicAssetsTests(unittest.TestCase):
    def test_accepts_a_png_response(self):
        verify_png("image/png", b"\x89PNG\r\n\x1a\n" + b"data")

    def test_rejects_spa_fallback_even_when_http_status_is_200(self):
        for content_type, data in [
            ("text/html", b"<!doctype html>"),
            ("image/png", b"<!doctype html>"),
            ("text/html", b"\x89PNG\r\n\x1a\n"),
        ]:
            with self.subTest(content_type=content_type):
                with self.assertRaises(ValueError):
                    verify_png(content_type, data)


if __name__ == "__main__":
    unittest.main()
