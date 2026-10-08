import '../../../participant_member/component.dart';
import '../../../participant_muted/component.dart';
import '../../../participant_name/component.dart';
import '../../../voice_participant_card/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceParticipantRoomParticipantsGridRenderer
    on WorkspaceVoiceParticipantRoomContext {
  GridView renderVoiceParticipantRoomParticipantsGrid(
    int crossAxisCount,
    double cardHeight,
  ) => GridView.builder(
    key: const ValueKey('voice-participant-grid'),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisExtent: cardHeight,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
    ),
    itemCount: participants.length + 1,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemBuilder: (context, index) {
      if (index == 0) {
        return WorkspaceVoiceParticipantCard(
          key: const ValueKey('voice-participant-card:self'),
          state: state,
          name: state.profile?.displayName.trim().isNotEmpty == true
              ? state.profile!.displayName
              : 'Вы',
          avatarUrl: state.profile?.avatarUrl,
          muted: state.microphoneMuted,
          microphoneUnavailable: state.microphoneUnavailable,
          deafened: state.deafened,
          speaking: room?.localParticipant?.isSpeaking ?? false,
          isLocal: true,
          hasScreen: state.screenSharePhase == ScreenSharePhase.sharing,
          onScreenTap: state.screenSharePhase == ScreenSharePhase.sharing
              ? () => onScreenSelected(null)
              : null,
        );
      }
      final participant = participants[index - 1];
      final volume = state.participantVolume(participant);
      final hasScreen = participant.videoTrackPublications.any(
        (publication) =>
            publication.source == TrackSource.screenShareVideo &&
            !publication.muted,
      );
      return WorkspaceVoiceParticipantCard(
        key: ValueKey('voice-participant-card:${participant.sid}'),
        state: state,
        name: workspaceParticipantName(participant),
        avatarUrl: workspaceParticipantMember(state, participant)?.avatarUrl,
        muted: workspaceParticipantMuted(participant),
        speaking: participant.isSpeaking,
        volume: volume,
        onVolumeChanged: volume == null
            ? null
            : (level) =>
                  unawaited(state.setParticipantVolume(participant, level)),
        hasScreen: hasScreen,
        onScreenTap: hasScreen
            ? () => onScreenSelected(participant.identity)
            : null,
      );
    },
  );
}
