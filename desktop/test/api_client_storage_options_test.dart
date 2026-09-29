import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS session storage uses an isolated legacy Keychain service', () {
    expect(
      ApiClient.macOsSessionOptions.accountName,
      'ru.boohtacord.boohtacordDesktop.session.v2',
    );
    expect(ApiClient.macOsSessionOptions.usesDataProtectionKeychain, isFalse);
  });
}
