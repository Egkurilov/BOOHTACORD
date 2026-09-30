import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'macOS session storage uses the isolated v3 legacy Keychain service',
    () {
      expect(
        ApiClient.macOsSessionOptions.accountName,
        'ru.boohtacord.boohtacordDesktop.session.v3',
      );
      expect(ApiClient.macOsSessionOptions.usesDataProtectionKeychain, isFalse);
    },
  );
}
