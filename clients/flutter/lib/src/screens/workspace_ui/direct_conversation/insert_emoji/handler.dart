import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceInsertEmojiBinding
    on WorkspaceDirectConversationStateContext {
  @override
  void workspaceInsertEmoji(String emoji) {
    executeWorkspaceDirectConversationStateWorkspaceInsertEmoji(emoji);
  }
}

extension WorkspaceDirectConversationStateWorkspaceInsertEmojiAction
    on WorkspaceDirectConversationStateContext {
  void executeWorkspaceDirectConversationStateWorkspaceInsertEmoji(
    String emoji,
  ) {
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
