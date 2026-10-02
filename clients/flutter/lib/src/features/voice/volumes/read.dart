import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

extension VoiceVolumesRead on VoiceController {
  String? voiceAccountId(RemoteParticipant participant) {
    final metadata = participant.metadata;
    if (metadata == null || !metadata.startsWith('account:')) return null;
    final accountId = metadata.substring('account:'.length);
    return accountId.isEmpty ? null : accountId;
  }

  RemoteParticipant? voiceParticipantForAccount(String accountId) => room
      ?.remoteParticipants
      .values
      .where((participant) => voiceAccountId(participant) == accountId)
      .firstOrNull;

  int? participantVolume(RemoteParticipant participant) {
    final accountId = voiceAccountId(participant);
    return accountId == null
        ? null
        : voiceVolumePreferences?.participant(accountId) ?? 100;
  }

  int? screenShareVolume(RemoteParticipant participant) {
    final accountId = voiceAccountId(participant);
    return accountId == null
        ? null
        : voiceVolumePreferences?.screen(accountId) ?? 100;
  }

  bool screenShareAudioMuted(RemoteParticipant participant) =>
      mutedScreenShareAudioIdentities.contains(participant.identity);
}
