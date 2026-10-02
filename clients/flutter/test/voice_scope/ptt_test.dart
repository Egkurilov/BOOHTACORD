import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'PTT focus loss queues mute after an in-flight microphone enable',
    () async {
      final h = VoiceHarness();
      addTearDown(h.dispose);
      h.owner.room = h.room;
      h.owner.voicePhase = VoicePhase.connected;
      h.owner.audioActivationMode = AudioActivationMode.ptt;
      h.owner.microphoneMuted = true;
      final down = h.owner.setPushToTalkPressed(true);
      await h.room.localParticipant.started.future;
      final focusLost = h.owner.setPushToTalkPressed(false);
      expect(h.owner.pushToTalkPressed, isFalse);
      h.room.localParticipant.capture.complete();
      await Future.wait([down, focusLost]);
      expect(h.room.localParticipant.enabled, [true, false]);
      expect(h.owner.microphoneMuted, isTrue);
      expect(h.owner.pushToTalkPressed, isFalse);
    },
  );
}
