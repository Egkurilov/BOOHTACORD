import 'package:livekit_client/livekit_client.dart';

import '../../features/voice/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppVoiceVolumesAccess on AppOwners {
  String? get voiceVolumeWarning => voice.voiceVolumeWarning;
  Future<void> resetAudioVolumes() => voice.resetAudioVolumes();
  Future<void> flushVoiceVolumes() => voice.flushVoiceVolumes();
  RemoteParticipant? voiceParticipantForAccount(String id) =>
      voice.voiceParticipantForAccount(id);

  int? participantVolume(RemoteParticipant participant) =>
      voice.participantVolume(participant);

  int? screenShareVolume(RemoteParticipant participant) =>
      voice.screenShareVolume(participant);

  bool screenShareAudioMuted(RemoteParticipant participant) =>
      voice.screenShareAudioMuted(participant);

  Future<void> toggleScreenShareAudio(RemoteParticipant participant) =>
      voice.toggleScreenShareAudio(participant);

  Future<void> setScreenShareAudioMuted(
    RemoteParticipant participant,
    bool muted,
  ) => voice.setScreenShareAudioMuted(participant, muted);

  Future<void> setParticipantVolume(
    RemoteParticipant participant,
    num percent,
  ) => voice.setParticipantVolume(participant, percent);

  Future<void> setScreenShareVolume(
    RemoteParticipant participant,
    num percent,
  ) => voice.setScreenShareVolume(participant, percent);
}
