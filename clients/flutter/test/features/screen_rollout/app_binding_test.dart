import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/app/media_preferences/screen.dart';
import 'package:boohtacord_desktop/src/app/account_lifecycle/clear.dart';
import 'package:boohtacord_desktop/src/features/screen/preferences/store.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('real app restores idle preference without Room or capture; cleanup only resets memory', () async {
    final app = AppState(ApiClient()); addTearDown(app.dispose);
    app.session.user = const SessionUser(accountId: 'a', role: 'MEMBER');
    final initial = app.screen.quality;
    const quality = ScreenShareQuality(resolution: 1440, frameRate: 60);
    final store = ScreenQualityPreferences(app.api.baseUrl, 'a');
    await store.save(quality); await app.restoreScreenPreferences();
    expect(app.screen.quality, quality); expect(app.voice.room, null);
    expect(app.screen.phase, ScreenSharePhase.idle); expect(app.screen.activeTrack, null);
    app.clearPrivateCaches(); expect(app.screen.quality, initial);
    expect(await store.read(), quality);
  });
  test('origin/account/logout boundaries discard captured pending intent', () async {
    final app = AppState(ApiClient()); addTearDown(app.dispose);
    app.session.user = const SessionUser(accountId: 'a', role: 'MEMBER');
    final previous = app.captureScreenPreferences()!;
    app.session.user = const SessionUser(accountId: 'b', role: 'MEMBER');
    expect(await previous.save(ScreenShareQuality.balanced), false);
    final oldOrigin = app.captureScreenPreferences()!;
    app.api.transport.session.baseUrl = 'https://other.test/api';
    expect(await oldOrigin.save(ScreenShareQuality.balanced), false);
    final next = app.captureScreenPreferences()!; app.session.scope.close();
    expect(await next.save(ScreenShareQuality.balanced), false);
    expect(await next.read(), null);
  });
  test('preference restore cannot apply quality to an active publication', () async {
    final app = AppState(ApiClient()); addTearDown(app.dispose);
    final initial = app.screen.quality;
    app.session.user = const SessionUser(accountId: 'a', role: 'MEMBER');
    await app.captureScreenPreferences()!.save(ScreenShareQuality.balanced);
    app.screen.phase = ScreenSharePhase.sharing;
    await app.restoreScreenPreferences();
    expect(app.screen.quality, initial);
  });
}
