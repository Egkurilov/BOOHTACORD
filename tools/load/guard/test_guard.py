import unittest
from tools.load.guard.ownership import validate_identity
from tools.load.guard.metrics import aggregate


class GuardTests(unittest.TestCase):
    def test_refuse_foreign_fixture(self):
        validate_identity('qa-client-0123456789abcdef', 'qa', 'https://localhost:4810')
        for values in (('production', 'qa', 'https://localhost:4810'),
                       ('qa-client-0123456789abcdef', 'production', 'https://localhost:4810'),
                       ('qa-client-0123456789abcdef', 'qa', 'https://boohtacord.ru')):
            with self.assertRaises(ValueError):
                validate_identity(*values)

    def test_metrics_drop_labels_and_unknown_content(self):
        values = aggregate('go_goroutines 11\npassword{user="secret"} 99\n'
                           'voice_platform_api_requests_total{route="secret"} 2\n'
                           'voice_platform_api_requests_total{route="other"} 3\n')
        self.assertEqual(values['go_goroutines'], 11)
        self.assertEqual(values['voice_platform_api_requests_total'], 5)
        self.assertNotIn('secret', str(values))


if __name__ == '__main__':
    unittest.main()
