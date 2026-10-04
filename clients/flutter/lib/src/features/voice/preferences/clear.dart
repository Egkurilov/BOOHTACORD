import 'dart:async';

import '../lifecycle/controller.dart';

extension VoiceAccountPreferences on VoiceController {
  void clearAccountPreferences() {
    cancelVoiceShortcuts(release: true);
    microphoneShortcut = deafenShortcut = null;
    audioPreferences = null;
    disconnect.reset();
    final previous = voiceVolumePreferences;
    unawaited(
      previous?.flush().catchError((Object _) {}) ?? Future<void>.value(),
    );
    voiceVolumePreferences = null;
    voiceVolumeWarning = null;
    audioActivationMode = AudioActivationMode.vad;
    pushToTalkKeyId = null;
    pushToTalkKeyLabel = null;
    pushToTalkPressed = false;
    audioActivationError = null;
    revokedVoiceLeasesDuringJoin.clear();
  }
}
