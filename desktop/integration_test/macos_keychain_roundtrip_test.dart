import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:boohtacord_desktop/src/services/api_client.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS isolated legacy Keychain can write, read and delete', (
    tester,
  ) async {
    const key = '__qa60_macos_keychain_roundtrip__';
    const value = 'non-secret-keychain-test-value';
    const storage = FlutterSecureStorage(
      mOptions: ApiClient.macOsSessionOptions,
    );

    await storage.delete(key: key);
    try {
      expect(await storage.read(key: key), isNull);
      await storage.write(key: key, value: value);
      expect(await storage.read(key: key), value);
      await storage.delete(key: key);
      expect(await storage.read(key: key), isNull);
    } finally {
      await storage.delete(key: key);
    }
  });
}
