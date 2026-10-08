import '../../show_screen_share_setup/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceRoomStateWorkspaceToggleLocalScreenShareBinding
    on WorkspaceVoiceRoomStateContext {
  @override
  Future<void> workspaceToggleLocalScreenShare(AppState state) {
    return executeWorkspaceVoiceRoomStateWorkspaceToggleLocalScreenShare(state);
  }
}

extension WorkspaceVoiceRoomStateWorkspaceToggleLocalScreenShareAction
    on WorkspaceVoiceRoomStateContext {
  Future<void> executeWorkspaceVoiceRoomStateWorkspaceToggleLocalScreenShare(
    AppState state,
  ) async {
    await workspaceShowScreenShareSetup(context, state);
  }
}
