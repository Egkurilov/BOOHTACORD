# macOS Keychain integration QA

This isolated host keeps `integration_test` out of the production Flutter
package's plugin registrant, so Android release builds cannot accidentally
register the test-only Android plugin.

Run the real Keychain round-trip test on macOS with:

```sh
cd desktop/qa/macos_keychain_integration
flutter pub get --enforce-lockfile
flutter test integration_test/macos_keychain_roundtrip_test.dart -d macos
flutter analyze integration_test/macos_keychain_roundtrip_test.dart
```
