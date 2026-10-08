import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspacePickEmojiBinding
    on WorkspaceConversationStateContext {
  @override
  Future<void> workspacePickEmoji() {
    return executeWorkspaceConversationStateWorkspacePickEmoji();
  }
}

extension WorkspaceConversationStateWorkspacePickEmojiAction
    on WorkspaceConversationStateContext {
  Future<void> executeWorkspaceConversationStateWorkspacePickEmoji() async {
    final emoji = await showMessageEmojiPicker(context);
    if (!mounted || emoji == null) return;
    workspaceInsertEmoji(emoji);
  }
}
