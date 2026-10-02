import '../lifecycle/controller.dart';

extension VoiceAccountPreferences on VoiceController {
  void clearAccountPreferences() {
    voiceVolumePreferences = null;
    audioActivationMode = AudioActivationMode.vad;
    pushToTalkKeyId = null;
    pushToTalkKeyLabel = null;
    pushToTalkPressed = false;
    audioActivationError = null;
    revokedVoiceLeasesDuringJoin.clear();
  }
}
