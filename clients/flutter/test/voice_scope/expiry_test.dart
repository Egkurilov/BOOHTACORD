import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';

import 'fakes.dart';
import 'api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'session expiry disconnects a pending voice room before connect completes',
    () async {
      final api = DelayedVoiceApi();
      final room = PendingVoiceRoom();
      final state = AppState(api, voiceRoomFactory: (_) => room)
        ..phase = AppPhase.ready;
      addTearDown(state.dispose);
      addTearDown(room.events.dispose);
      api.credential.complete(('lease', credential));
      final joining = state.joinVoice(channel);
      await Future<void>.delayed(Duration.zero);
      expect(room.connectCalled, isTrue);
      api.onUnauthorized!();
      for (var attempt = 0; attempt < 10 && room.disconnected == 0; attempt++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(room.disconnected, greaterThan(0));
      room.connecting.complete();
      await joining;
      expect(state.phase, AppPhase.signedOut);
      expect(state.room, isNull);
      expect(room.localParticipant.enabled, isEmpty);
    },
  );
}
