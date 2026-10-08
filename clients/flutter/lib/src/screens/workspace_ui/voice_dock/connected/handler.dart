import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceDockWorkspaceConnectedBinding on WorkspaceVoiceDockContext {
  @override
  bool get workspaceConnected {
    return executeWorkspaceVoiceDockWorkspaceConnected();
  }
}

extension WorkspaceVoiceDockWorkspaceConnectedAction
    on WorkspaceVoiceDockContext {
  bool executeWorkspaceVoiceDockWorkspaceConnected() =>
      state.voicePhase == VoicePhase.connected ||
      state.voicePhase == VoicePhase.listener;
}
