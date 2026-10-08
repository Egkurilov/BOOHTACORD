import 'room_content/handler.dart';
import '../../participant_name/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceRoomStateBuildBinding on WorkspaceVoiceRoomStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceVoiceRoomStateBuild(context);
  }
}

extension WorkspaceVoiceRoomStateBuildAction on WorkspaceVoiceRoomStateContext {
  Widget executeWorkspaceVoiceRoomStateBuild(BuildContext context) {
    final state = widget.state;
    final channel = widget.channel;
    final room = state.room;
    final active = state.voiceChannel?.id == channel.id;
    return AnimatedBuilder(
      animation: Listenable.merge([?room, state]),
      builder: (context, _) {
        final participants =
            room?.remoteParticipants.values.toList() ?? const [];
        final screens = participants
            .where(
              (participant) => participant.videoTrackPublications.any(
                isDiscoverableRemoteScreenPublication,
              ),
            )
            .toList(growable: false);
        final selectedScreen = screens
            .where(
              (participant) =>
                  participant.identity == widget.selectedScreenIdentity,
            )
            .firstOrNull;
        final selectedScreenPublication = selectedScreen == null
            ? null
            : firstDiscoverableRemoteScreenPublication(selectedScreen);
        final selectedTrack = selectedScreenPublication?.track as VideoTrack?;
        final localScreenPublication =
            state.screenSharePhase == ScreenSharePhase.sharing
            ? room?.localParticipant?.getTrackPublicationBySource(
                TrackSource.screenShareVideo,
              )
            : null;
        final localScreenTrack = localScreenPublication?.track as VideoTrack?;
        final selectedAudioPublication = selectedScreen == null
            ? null
            : screenShareAudioPublication(selectedScreen);
        final participantCount = active ? participants.length + 1 : 0;
        final showingLocalScreen =
            selectedTrack == null &&
            localScreenTrack != null &&
            widget.selectedScreenIdentity == null;
        final viewerTrack =
            selectedTrack ?? (showingLocalScreen ? localScreenTrack : null);
        final selectedName = selectedScreen != null
            ? workspaceParticipantName(selectedScreen)
            : showingLocalScreen
            ? 'ваш экран'
            : null;
        final viewerGeneration =
            selectedScreen == null || selectedScreenPublication == null
            ? localScreenPublication?.sid ?? viewerTrack
            : ScreenViewerPublicationGeneration(
                participantIdentity: selectedScreen.identity,
                publicationSid: selectedScreenPublication.sid,
              );
        final rendererOwner = screenVideoRendererOwner(
          selectedIdentity: widget.selectedScreenIdentity,
          selectedGeneration: viewerTrack == null ? null : viewerGeneration,
          pinnedIdentity: widget.pinnedScreenIdentity,
          pinnedMiniVisible: widget.pinnedMiniVisible,
          fullscreenSelection: widget.fullscreenSelection,
        );
        return renderVoiceRoomRoomContent(
          channel,
          selectedName,
          active,
          state,
          participantCount,
          context,
          viewerTrack,
          rendererOwner,
          screens,
          viewerGeneration,
          selectedScreen,
          selectedScreenPublication,
          localScreenTrack,
          showingLocalScreen,
          selectedTrack,
          localScreenPublication,
          room,
          participants,
          selectedAudioPublication,
        );
      },
    );
  }
}
