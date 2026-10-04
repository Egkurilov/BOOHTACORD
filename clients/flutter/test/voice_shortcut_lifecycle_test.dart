import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/microphone/shortcut.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';

import 'package:boohtacord_desktop/src/features/voice/preferences/clear.dart';

import 'voice_scope/fakes.dart';
import 'voice_scope/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native execution blocks listener/PTT/reconnect and clears account state',
    () async {
      final h = VoiceHarness();
      addTearDown(h.dispose);
      h.owner.room = h.room;
      h.owner.voiceChannel = channel;
      h.owner.voicePhase = VoicePhase.reconnecting;
      expect(await h.owner.runVoiceShortcut('microphone'), 'blocked');
      h.owner.voicePhase = VoicePhase.listener;
      h.owner.listenerOnly = true;
      expect(await h.owner.runVoiceShortcut('microphone'), 'blocked');
      h.owner.voicePhase = VoicePhase.connected;
      h.owner.listenerOnly = false;
      h.owner.audioActivationMode = AudioActivationMode.ptt;
      expect(await h.owner.runVoiceShortcut('microphone'), 'blocked');
      expect(h.room.localParticipant.enabled, isEmpty);
      h.owner.microphoneShortcut = const VoiceShortcutBinding(
        keyId: 42,
        label: 'M',
        control: true,
      );
      h.owner.voiceShortcutStatus = 'old';
      h.owner.clearAccountPreferences();
      expect(h.owner.microphoneShortcut, isNull);
      expect(h.owner.voiceShortcutStatus, isNull);
    },
  );
  test(
    'pending native command is serialized and cancel suppresses its status',
    () async {
      final h = VoiceHarness();
      addTearDown(h.dispose);
      h.owner.room = h.room;
      h.owner.voiceChannel = channel;
      h.owner.voicePhase = VoicePhase.connected;
      h.owner.microphoneMuted = true;
      final pending = h.owner.runVoiceShortcut('microphone');
      expect(await h.owner.runVoiceShortcut('deafen'), 'blocked');
      h.owner.cancelVoiceShortcuts();
      h.room.localParticipant.capture.complete();
      await pending;
      expect(h.owner.voiceShortcutStatus, isNull);
    },
  );
}
