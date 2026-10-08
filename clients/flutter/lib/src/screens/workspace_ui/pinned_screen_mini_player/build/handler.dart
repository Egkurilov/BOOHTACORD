import 'floating_surface/handler.dart';
import '../../participant_name/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspacePinnedScreenMiniPlayerBuildBinding
    on WorkspacePinnedScreenMiniPlayerContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspacePinnedScreenMiniPlayerBuild(context);
  }
}

extension WorkspacePinnedScreenMiniPlayerBuildAction
    on WorkspacePinnedScreenMiniPlayerContext {
  Widget executeWorkspacePinnedScreenMiniPlayerBuild(BuildContext context) =>
      AnimatedBuilder(
        animation: state.room ?? state,
        builder: (context, _) {
          final participant = state.room?.remoteParticipants[identity];
          final publication = participant == null
              ? null
              : firstDiscoverableRemoteScreenPublication(participant);
          final publicationSid = publication?.sid;
          final track = publication?.track as VideoTrack?;
          final hasAudio =
              participant != null &&
              screenShareAudioPublication(participant) != null;
          final screenVolume = participant == null
              ? null
              : state.screenShareVolume(participant);
          final name = participant == null
              ? 'Демонстрация'
              : workspaceParticipantName(participant);
          final miniGeneration = publication == null
              ? null
              : ScreenViewerPublicationGeneration(
                  participantIdentity: identity,
                  publicationSid: publication.sid,
                );
          final selectedFullscreen = fullscreenSelection;
          final miniIsSelectedPublication = selectedIdentity == identity;
          final selectedGeneration = miniIsSelectedPublication
              ? miniGeneration
              : null;
          final rendererOwner = screenVideoRendererOwner(
            selectedIdentity: selectedIdentity,
            selectedGeneration: selectedGeneration,
            pinnedIdentity: identity,
            pinnedMiniVisible: pinnedMiniVisible,
            fullscreenSelection: fullscreenSelection,
          );

          return renderPinnedScreenMiniPlayerFloatingSurface(
            name,
            hasAudio,
            participant,
            screenVolume,
            track,
            publicationSid,
            publication,
            rendererOwner,
            miniGeneration,
            selectedGeneration,
            selectedFullscreen,
          );
        },
      );
}
