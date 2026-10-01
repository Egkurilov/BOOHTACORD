import unittest
from .dart import violations


class DartImportTests(unittest.TestCase):
    def test_missing_local_dependency_is_visible_before_clean_checkout(self):
        sources = {'clients/flutter/lib/src/services/api.dart': "import '../features/attachments/api.dart';"}
        self.assertIn('absent or ignored', violations(sources)[0])
        sources['clients/flutter/lib/src/features/attachments/api.dart'] = "import 'dart:io';"
        self.assertEqual(violations(sources), [])

    def test_package_import_resolves_to_the_single_flutter_project(self):
        sources = {'clients/flutter/test/api_test.dart': "import 'package:boohtacord_desktop/src/api.dart';",
                   'clients/flutter/lib/src/api.dart': "import 'package:http/http.dart';"}
        self.assertEqual(violations(sources), [])

    def test_feature_owner_cannot_depend_on_app_state(self):
        sources = {'clients/flutter/lib/src/features/voice/controller.dart': "import '../../app_state.dart';",
                   'clients/flutter/lib/src/app_state.dart': ''}
        self.assertIn('depends on application UI', violations(sources)[0])
