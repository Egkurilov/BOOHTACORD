import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/android_audio_devices.dart';
import '../../../services/voice_volume_preferences.dart';
import '../../../services/voice_lease_revocation.dart';
import '../../../services/voice_audio_config.dart';
import '../lifecycle/controller.dart';

class CancelledVoiceAdmission implements Exception {}

extension VoiceAdmissionPrepare on VoiceController {
  void checkAdmission(SessionTicket ticket, int revision, String lease) {
    if (!active(ticket, revision)) throw CancelledVoiceAdmission();
    final reason = revokedVoiceLeasesDuringJoin[lease];
    if (reason != null) {
      throw VoiceLeaseRevocation(leaseId: lease, reason: reason);
    }
  }

  Future<void> loadVoiceVolumes(
    SessionTicket ticket,
    int revision,
    String lease,
  ) async {
    final account = readUser();
    if (account == null) return;
    await flushVoiceVolumes();
    checkAdmission(ticket, revision, lease);
    final preferences = await VoiceVolumePreferences.open(account.accountId, origin: api.baseUrl);
    checkAdmission(ticket, revision, lease);
    if (readUser()?.accountId != account.accountId || !preferences.belongsTo(account.accountId, api.baseUrl)) throw CancelledVoiceAdmission();
    voiceVolumePreferences = preferences;
    volumePreferenceOutcome(preferences.status);
  }

  RoomOptions voiceRoomOptions() => RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    defaultAudioCaptureOptions: audio.captureOptions,
    defaultAudioPublishOptions: voiceMicrophonePublishOptions,
    defaultAudioOutputOptions: AudioOutputOptions(
      deviceId:
          AndroidAudioDevices.isNativeOutputRoute(selectedAudioOutputId) ||
              (AndroidAudioDevices.isAndroid &&
                  selectedAudioOutputId == 'default')
          ? null
          : selectedAudioOutputId,
    ),
  );
  Future<void> selectVoiceOutput() async {
    if (AndroidAudioDevices.isNativeOutputRoute(selectedAudioOutputId) &&
        !await AndroidAudioDevices.selectNativeOutput(selectedAudioOutputId!)) {
      throw StateError('Android не смог выбрать сохранённый аудиовыход.');
    }
  }
}
