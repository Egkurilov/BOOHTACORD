import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/app/account_lifecycle/clear.dart';
import 'package:boohtacord_desktop/src/app/overlay_preferences/actions.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/preferences.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/settings/model.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('boohtacord/voice_overlay');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(channel, (call) async => true);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'logout rejects old placement before new account settings finish restoring',
    () async {
      final app = AppState(ApiClient());
      addTearDown(app.dispose);
      app.session.user = const SessionUser(accountId: 'a', role: 'member');
      app.voiceOverlayPreferences = await VoiceOverlayPreferences.open('a');
      app.bindOverlayPlacement();
      await app.saveOverlayConfiguration(
        const OverlayConfiguration(enabled: true, scale: 2),
      );
      final bridge = app.voiceOverlayWindowsClient!.configuration;
      final oldRevision = bridge.revision;
      app.session.scope.close();
      app.clearPrivateCaches();
      app.session.scope.begin();
      app.session.user = const SessionUser(accountId: 'b', role: 'member');
      app.voiceOverlayPreferences = await VoiceOverlayPreferences.open('b');
      app.bindOverlayPlacement();
      await bridge.receive(
        MethodCall('placementChanged', {
          'revision': oldRevision,
          'x': .2,
          'y': .7,
          'monitor': 'old',
          'editing': true,
        }),
      );
      await bridge.receive(
        MethodCall('hotkeyConflict', {'revision': oldRevision}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        app.voiceOverlayPreferences!.configuration.toJson(),
        const OverlayConfiguration().toJson(),
      );
      expect(bridge.current.enabled, isFalse);
      expect(bridge.editing, isFalse);
      expect(app.error, isNull);
    },
  );

  test(
    'late native configuration completion cannot enable a signed out account',
    () async {
      final pending = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        return call.method == 'setConfiguration' ? pending.future : null;
      });
      final app = AppState(ApiClient());
      addTearDown(app.dispose);
      app.session.user = const SessionUser(accountId: 'a', role: 'member');
      app.voiceOverlayPreferences = await VoiceOverlayPreferences.open('a');
      final saving = app.saveOverlayConfiguration(
        const OverlayConfiguration(enabled: true),
      );
      await Future<void>.delayed(Duration.zero);
      app.session.scope.close();
      app.clearPrivateCaches();
      pending.complete(true);
      expect(await saving, isFalse);
      expect(app.voiceOverlay.enabled, isFalse);
      expect(
        app.voiceOverlayWindowsClient!.configuration.current.enabled,
        isFalse,
      );
    },
  );
}
