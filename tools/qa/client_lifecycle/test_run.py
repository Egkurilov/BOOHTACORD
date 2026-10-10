import unittest

from .run import viewport_profile


class ViewportProfileTests(unittest.TestCase):
    def test_mobile_profile_matches_reference_css_viewport_and_touch_surface(self):
        self.assertEqual(viewport_profile(393), {
            'name': 'mobile-393x852',
            'width': 393,
            'height': 852,
            'is_mobile': True,
            'device_scale_factor': 3,
            'has_touch': True,
        })

    def test_mobile_profile_matches_issue_290_reference_viewport(self):
        self.assertEqual(viewport_profile(390), {
            'name': 'mobile-390x844',
            'width': 390,
            'height': 844,
            'is_mobile': True,
            'device_scale_factor': 3,
            'has_touch': True,
        })

    def test_tablet_and_desktop_profiles_keep_explicit_target_heights(self):
        self.assertEqual(viewport_profile(1024), {
            'name': 'tablet-1024x768',
            'width': 1024,
            'height': 768,
            'is_mobile': False,
            'device_scale_factor': 1,
            'has_touch': False,
        })
        self.assertEqual(viewport_profile(1440), {
            'name': 'desktop-1440x900',
            'width': 1440,
            'height': 900,
            'is_mobile': False,
            'device_scale_factor': 2,
            'has_touch': False,
        })

    def test_unsupported_width_is_rejected(self):
        with self.assertRaises(ValueError):
            viewport_profile(391)


if __name__ == '__main__':
    unittest.main()
