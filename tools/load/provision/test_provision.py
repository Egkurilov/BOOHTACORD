import unittest
from tools.load.provision.dataset import account_rows, validate_count


class ProvisionTests(unittest.TestCase):
    def test_only_bounded_synthetic_users(self):
        rows = account_rows(100)
        self.assertEqual(len({row['ID'] for row in rows}), 100)
        self.assertTrue(all(row['Login'].startswith('qa_load_') for row in rows))
        for number in (0, 101, -1):
            with self.assertRaises(ValueError):
                validate_count(number)


if __name__ == '__main__':
    unittest.main()
