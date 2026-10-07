import unittest
from .web import violations


class WebBoundaryTests(unittest.TestCase):
    def test_feature_cannot_import_shell_even_dynamically(self):
        sources = {'clients/web/src/voice/control.ts': ['../workspace/WorkspaceApp.vue'],
                   'clients/web/src/workspace/WorkspaceApp.vue': []}
        self.assertIn('composition', violations(sources)[0])

    def test_shared_utility_cannot_import_feature(self):
        sources = {'clients/web/src/validation/value.ts': ['../identity/session'],
                   'clients/web/src/identity/session.ts': []}
        self.assertIn('shared', violations(sources)[0])

    def test_shell_coordinates_features(self):
        sources = {'clients/web/src/workspace/WorkspaceApp.vue': ['../admin/panel/Admin.vue'],
                   'clients/web/src/admin/panel/Admin.vue': []}
        self.assertEqual(violations(sources), [])

    def test_missing_local_dependency_is_rejected(self):
        sources = {'clients/web/src/workspace/WorkspaceApp.vue': ['./gone.vue']}
        self.assertIn('missing', violations(sources)[0])

    def test_feature_can_import_shared_contract_json(self):
        sources = {'clients/web/src/voice/policy.ts': ['../../../../contracts/screen-profile.json'],
                   'contracts/screen-profile.json': []}
        self.assertEqual(violations(sources), [])
