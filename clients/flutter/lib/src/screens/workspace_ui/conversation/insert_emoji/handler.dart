import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceInsertEmojiBinding
    on WorkspaceConversationStateContext {
  @override
  void workspaceInsertEmoji(String emoji) {
    executeWorkspaceConversationStateWorkspaceInsertEmoji(emoji);
  }
}

extension WorkspaceConversationStateWorkspaceInsertEmojiAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateWorkspaceInsertEmoji(String emoji) {
    final insertion = insertMessageEmoji(
      workspaceController.text,
      workspaceController.selection,
      emoji,
    );
    workspaceController.value = TextEditingValue(
      text: insertion.text,
      selection: insertion.selection,
      composing: TextRange.empty,
    );
    workspaceComposerFocus.requestFocus();
    workspaceRememberDraft();
  }
}
