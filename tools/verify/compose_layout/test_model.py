import copy
import unittest
from .model import compare


class ComposeParityTests(unittest.TestCase):
    def setUp(self):
        self.before = {'name': 'voice-platform', 'services': {'api': {
            'image': 'api@sha256:abc', 'build': {'context': '/repo/backend'},
            'volumes': [{'type': 'bind', 'source': '/repo/docker/Caddyfile', 'read_only': True}],
            'environment': {'DATABASE_URL': 'test'}, 'networks': {'private': None},
            'depends_on': {'migrate': {'condition': 'service_completed_successfully'}}}},
            'volumes': {'postgres-data': {'name': 'voice-platform_postgres-data'}}}
        self.after = copy.deepcopy(self.before)
        self.after['services']['api'].pop('build')
        self.after['services']['api']['volumes'][0]['source'] = '/repo/deploy/caddy/Caddyfile'

    def test_only_relocation_and_build_removal_are_allowed(self):
        compare(self.before, self.after)

    def test_volume_identity_or_migration_dependency_change_is_rejected(self):
        for target in ('volume', 'migration', 'environment', 'network', 'project'):
            with self.subTest(target=target):
                changed = copy.deepcopy(self.after)
                if target == 'volume': changed['volumes']['postgres-data']['name'] = 'new-data'
                if target == 'migration': changed['services']['api']['depends_on'] = {}
                if target == 'environment': changed['services']['api']['environment'] = {}
                if target == 'network': changed['services']['api']['networks'] = {'edge': None}
                if target == 'project': changed['name'] = 'new-project'
                with self.assertRaises(ValueError): compare(self.before, changed)

    def test_build_in_production_is_rejected(self):
        self.after['services']['api']['build'] = {'context': '/repo/backend'}
        with self.assertRaises(ValueError): compare(self.before, self.after)
