import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class DelayedVoiceApi extends ApiClient {
  final credential = Completer<(String, VoiceCredential)>();
  @override
  Future<(String, VoiceCredential)> voiceCredential(
    String channelId, {
    bool transfer = false,
  }) => credential.future;
  @override
  Future<void> logout() async {}
  @override
  Future<void> releaseVoice(String leaseId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  test(
    'a late voice admission failure cannot restore voice after logout',
    () async {
      final api = DelayedVoiceApi();
      final state = AppState(api)..phase = AppPhase.ready;
      addTearDown(state.dispose);
      final joining = state.joinVoice(
        const GuildChannel(
          id: 'voice',
          name: 'Voice',
          kind: ChannelKind.voice,
          admissionClosed: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await state.logout();
      api.credential.completeError(
        const ApiFailure('unavailable', status: 503, code: 'UNAVAILABLE'),
      );
      await joining;
      expect(state.phase, AppPhase.signedOut);
      expect(state.voicePhase, VoicePhase.idle);
      expect(state.room, isNull);
      expect(state.error, isNull);
    },
  );
}
