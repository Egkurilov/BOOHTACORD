import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspacePickEmojiBinding
    on WorkspaceDirectConversationStateContext {
  @override
  Future<void> workspacePickEmoji() {
    return executeWorkspaceDirectConversationStateWorkspacePickEmoji();
  }
}

extension WorkspaceDirectConversationStateWorkspacePickEmojiAction
    on WorkspaceDirectConversationStateContext {
  Future<void>
  executeWorkspaceDirectConversationStateWorkspacePickEmoji() async {
    final emoji = await showMessageEmojiPicker(context);
    if (!mounted || emoji == null) return;
    workspaceInsertEmoji(emoji);
  }
}
