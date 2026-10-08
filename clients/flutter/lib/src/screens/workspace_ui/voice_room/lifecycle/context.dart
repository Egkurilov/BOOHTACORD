import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceVoiceRoomStateContext
    extends State<WorkspaceVoiceRoom> {
  Future<void> workspaceToggleLocalScreenShare(AppState state);
  Future<void> workspaceOpenScreenFullscreen({
    required VideoTrack track,
    required String publisherName,
    required String? publisherIdentity,
    required Object viewerGeneration,
    required VoidCallback? onFirstFrameRendered,
    required bool showingLocalScreen,
  });
  void workspaceMutateView(VoidCallback action) => setState(action);
}
