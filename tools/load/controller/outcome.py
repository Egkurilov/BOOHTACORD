"""Reject malformed driver output and never turn cleanup/criterion failures green."""
import json


def outcome(stdout, exit_code):
    driver = json.loads(stdout)
    if not isinstance(driver, dict) or driver.get('SchemaVersion') != 1:
        raise ValueError('Malformed driver envelope')
    for field in ('Outcome', 'Cleanup', 'Criteria', 'Routes', 'Resources', 'Phases'):
        if field not in driver:
            raise ValueError('Incomplete driver envelope')
    criteria = driver['Criteria']
    if not isinstance(criteria, dict):
        raise ValueError('Invalid criteria envelope')
    passed = exit_code == 0 and driver['Outcome'] == 'PASS' and driver['Cleanup'] == 'PASS'
    passed = passed and not any(status == 'FAIL' for status in criteria.values())
    return driver, 'PASS' if passed else 'FAIL'
