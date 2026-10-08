import '../../native_bindings.dart';

import '../lifecycle/context.dart';

extension SynchronizePinnedPublicationAction on WorkspaceScreenStateContext {
  void synchronizePinnedPublication() {
    final pinnedIdentity = workspacePinnedScreenIdentity;
    final pinnedParticipant = pinnedIdentity == null
        ? null
        : widget.state.room?.remoteParticipants[pinnedIdentity];
    final room = widget.state.room;
    final pinnedPublicationPresent =
        pinnedParticipant?.videoTrackPublications.any(
          (item) => item.source == TrackSource.screenShareVideo,
        ) ??
        false;
    if (pinnedIdentity != null &&
        room != null &&
        pinnedScreenPublicationEnded(
          participantPresent: pinnedParticipant != null,
          publicationPresent: pinnedPublicationPresent,
        )) {
      workspaceMutateView(() => workspacePinnedScreenIdentity = null);
    }
  }
}
