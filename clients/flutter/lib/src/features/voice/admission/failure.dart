import '../../../services/android_audio_devices.dart';
import '../../../services/voice_lease_revocation.dart';
import '../lifecycle/controller.dart';
extension VoiceAdmissionFailure on VoiceController {
  Future<void> failVoiceAdmission(Object cause, String? admittedLease, {bool presentCause = true}) async {
    stopVoiceConnectionStatsPolling();
    final revoked = revokedVoiceLeasesDuringJoin.remove(admittedLease);
    if (presentCause && admittedLease != null && revoked != null) disconnect.server(admittedLease, revoked);
    if (presentCause && admittedLease != null && cause is VoiceLeaseRevocation) disconnect.server(admittedLease, cause.reason);
    error = !presentCause ? null : disconnect.notice?.message ?? (revoked != null
        ? VoiceLeaseRevocation(
            leaseId: admittedLease!,
            reason: revoked,
          ).message
        : cause is VoiceLeaseRevocation
        ? cause.message
        : formatError(cause));
    voicePhase = presentCause ? VoicePhase.error : VoicePhase.idle;
    room = null;
    leaseId = null;
    voiceChannel = null;
    mutedScreenShareAudioIdentities.clear();
    try {
      await AndroidAudioDevices.clearNativeOutput();
    } catch (_) {}
  }
}
