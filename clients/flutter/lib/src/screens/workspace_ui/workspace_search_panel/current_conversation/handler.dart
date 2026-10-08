import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateWorkspaceCurrentConversationBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  ({String id, String label, bool direct})? workspaceCurrentConversation() {
    return executeWorkspaceWorkspaceSearchPanelStateWorkspaceCurrentConversation();
  }
}

extension WorkspaceWorkspaceSearchPanelStateWorkspaceCurrentConversationAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  ({String id, String label, bool direct})?
  executeWorkspaceWorkspaceSearchPanelStateWorkspaceCurrentConversation() {
    final direct = state.selectedDirectMessage;
    if (direct != null) {
      return (id: direct.id, label: direct.displayName, direct: true);
    }
    final channel = state.selectedChannel;
    if (channel?.kind == ChannelKind.text) {
      return (id: channel!.id, label: '#${channel.name}', direct: false);
    }
    return null;
  }
}
