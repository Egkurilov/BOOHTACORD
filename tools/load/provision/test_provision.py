import unittest
from tools.load.provision.dataset import account_rows, validate_count
from tools.load.provision.stack import Stack


class ProvisionTests(unittest.TestCase):
    def test_load_fixture_does_not_seed_browser_members(self):
        # Load provisioning expects a fresh database containing only the bootstrap admin.
        Stack.__new__(Stack).seed_admin_members()

    def test_only_bounded_synthetic_users(self):
        rows = account_rows(100)
        self.assertEqual(len({row['ID'] for row in rows}), 100)
        self.assertTrue(all(row['Login'].startswith('qa_load_') for row in rows))
        for number in (0, 101, -1):
            with self.assertRaises(ValueError):
                validate_count(number)


if __name__ == '__main__':
    unittest.main()
