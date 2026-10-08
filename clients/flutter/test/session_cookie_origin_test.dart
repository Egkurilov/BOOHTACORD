import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boohtacord_desktop/src/core/session/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy unscoped cookie is discarded during restore', () async {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie': 'vp_session=legacy-A',
    });
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://a.example/api/v1',
    });
    final session = SessionStore();
    await session.initialize();

    expect(await session.readCookie(), isNull);
  });

  test('cookie written for one origin is never read for another', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final session = SessionStore();
    final storage = FlutterSecureStorage();
    await session.setBaseUrl('https://a.example');
    await session.writeCookie('vp_session=only-A');

    expect(
      await storage.read(key: 'boohtacord_session_cookie'),
      isNull,
    );
    expect(
      await storage.read(
        key: 'boohtacord_session_cookie:https://a.example:443',
      ),
      'vp_session=only-A',
    );

    await session.setBaseUrl('https://b.example');
    expect(await session.readCookie(), isNull);
    await session.setBaseUrl('https://a.example');
    expect(await session.readCookie(), isNull);
  });
}
