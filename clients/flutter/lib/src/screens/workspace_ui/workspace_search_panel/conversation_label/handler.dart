import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateWorkspaceConversationLabelBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  String workspaceConversationLabel(SearchMessage message) {
    return executeWorkspaceWorkspaceSearchPanelStateWorkspaceConversationLabel(
      message,
    );
  }
}

extension WorkspaceWorkspaceSearchPanelStateWorkspaceConversationLabelAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  String executeWorkspaceWorkspaceSearchPanelStateWorkspaceConversationLabel(
    SearchMessage message,
  ) {
    if (message.kind == SearchMessageKind.directMessage) {
      return state.directMessages
              .where((value) => value.id == message.conversationId)
              .firstOrNull
              ?.displayName ??
          'Личный диалог';
    }
    final channel = state.topology?.categories
        .expand((category) => category.channels)
        .where((value) => value.id == message.conversationId)
        .firstOrNull;
    return channel == null ? 'Текстовый канал' : '#${channel.name}';
  }
}
