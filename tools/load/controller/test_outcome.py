import json
import unittest
from .outcome import outcome


class OutcomeTests(unittest.TestCase):
    def test_malformed_failed_cleanup_and_criteria_fail_closed(self):
        value = dict(SchemaVersion=1, Outcome='PASS', Cleanup='PASS', Criteria={'media': 'NOT_RUN'},
                     Routes={}, Resources=[], Phases=[])
        self.assertEqual(outcome(json.dumps(value), 0)[1], 'PASS')
        value['Cleanup'] = 'FAIL'
        self.assertEqual(outcome(json.dumps(value), 0)[1], 'FAIL')
        value['Cleanup'] = 'PASS'
        value['Criteria']['message'] = 'FAIL'
        self.assertEqual(outcome(json.dumps(value), 0)[1], 'FAIL')
        for bad in ('garbled stdout', '[]', '{}'):
            with self.assertRaises(ValueError):
                outcome(bad, 0)


if __name__ == '__main__':
    unittest.main()
