import 'feed.dart';
import 'projection.dart';
import 'roster_projection.dart';
import '../../../models.dart';
import '../lifecycle/controller.dart';
import '../roster_state/controller.dart';

VoiceOverlayFeed createCurrentVoiceOverlayFeed({
  required VoiceController voice,
  required VoiceRosterController roster,
  required String? Function() readAccountId,
}) =>
    VoiceOverlayFeed(
      sources: [voice, roster],
      project: (enabled, onlySpeakers) => currentVoiceOverlaySnapshot(
        voice: voice,
        roster: roster,
        accountId: readAccountId(),
        settings: VoiceOverlaySettings(
          enabled: enabled,
          onlySpeakers: onlySpeakers,
        ),
      ),
    );

VoiceOverlaySnapshot currentVoiceOverlaySnapshot({
  required VoiceController voice,
  required VoiceRosterController roster,
  required String? accountId,
  required VoiceOverlaySettings settings,
}) {
  final channelId = voice.voiceChannel?.id;
  final room = voice.room;
  String? rosterChannelId;
  final members = roster.voiceRosters;
  if (channelId != null && members != null) {
    for (final entry in members) {
      if (entry.channelId == channelId) {
        rosterChannelId = entry.channelId;
        break;
      }
    }
  }
  final status = switch (voice.voicePhase) {
    VoicePhase.connected || VoicePhase.listener =>
      VoiceOverlayVoiceStatus.connected,
    VoicePhase.reconnecting => VoiceOverlayVoiceStatus.reconnecting,
    _ => VoiceOverlayVoiceStatus.disconnected,
  };
  final speaking = <String>{};
  if (room != null && status == VoiceOverlayVoiceStatus.connected) {
    if (accountId != null &&
        room.localParticipant?.isSpeaking == true &&
        !voice.microphoneMuted) {
      speaking.add(accountId);
    }
    for (final participant in room.remoteParticipants.values) {
      final metadata = participant.metadata;
      if (participant.isSpeaking &&
          metadata != null &&
          metadata.startsWith('account:')) {
        speaking.add(metadata.substring('account:'.length));
      }
    }
  }
  final activeRoster = members
      ?.where((entry) => entry.channelId == channelId)
      .firstOrNull;
  final projectedRoster = activeRoster?.participants.map(
    (member) => member.accountId == accountId
        ? VoiceRosterMember(
            accountId: member.accountId,
            displayName: member.displayName,
            screenSharing: member.screenSharing,
            microphoneMuted: voice.microphoneMuted,
          )
        : member,
  );
  return projectVoiceOverlayRoster(
    settings: settings,
    voiceChannelId: room == null ? null : channelId,
    rosterChannelId: rosterChannelId,
    voiceStatus: status,
    roster: projectedRoster ?? const <VoiceRosterMember>[],
    speakingAccountIds: speaking,
  );
}
