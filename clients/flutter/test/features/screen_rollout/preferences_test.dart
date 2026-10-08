import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/features/screen/preferences/store.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('quality survives restart and remains isolated by account and origin', () async {
    final first = ScreenQualityPreferences('https://example.test/api', 'a');
    for (final resolution in ScreenShareQuality.resolutions) {
      for (final fps in ScreenShareQuality.frameRates) {
        final profile = ScreenShareQuality(resolution: resolution, frameRate: fps);
        expect(await first.save(profile), true);
        expect(await ScreenQualityPreferences('https://example.test:443', 'a').read(), profile);
      }
    }
    expect(await ScreenQualityPreferences('https://example.test', 'b').read(), null);
    expect(await ScreenQualityPreferences('https://other.test', 'a').read(), null);
  });
  test('legacy profile migrates on explicit write; future versions remain intact', () async {
    final store = ScreenQualityPreferences('https://example.test', 'a');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(store.key, 'P720_15');
    expect(await store.read(), ScreenShareQuality.balanced);
    expect(await store.save(ScreenShareQuality.desktopDefault), true);
    expect(jsonDecode(preferences.getString(store.key)!)['schema_version'], 1);
    const future = '{"schema_version":2,"profile_id":"P1440_60","future":true}';
    await preferences.setString(store.key, future);
    expect(await store.read(), null);
    expect(await store.save(ScreenShareQuality.balanced), false);
    expect(preferences.getString(store.key), future);
  });
  test('unknown profile/type is ignored without deleting stored data', () async {
    final store = ScreenQualityPreferences('https://example.test', 'a');
    final preferences = await SharedPreferences.getInstance();
    for (final raw in ['P2160_60', '{"schema_version":1,"profile_id":true}', 'bad']) {
      await preferences.setString(store.key, raw);
      expect(await store.read(), null); expect(preferences.getString(store.key), raw);
    }
    expect(await store.save(const ScreenShareQuality(resolution: 2160, frameRate: 60)), false);
  });
  test('closed account during preference open cannot read or write', () async {
    final opened = Completer<SharedPreferences>();
    var active = true;
    final store = ScreenQualityPreferences('https://example.test', 'a',
      open: () => opened.future, current: () => active);
    final saving = store.save(ScreenShareQuality.balanced);
    final reading = store.read(); active = false;
    opened.complete(await SharedPreferences.getInstance());
    expect(await saving, false); expect(await reading, null);
    expect((await SharedPreferences.getInstance()).getString(store.key), null);
  });
}
