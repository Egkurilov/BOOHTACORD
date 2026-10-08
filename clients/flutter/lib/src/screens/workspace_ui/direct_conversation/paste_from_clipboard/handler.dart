import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspacePasteFromClipboardBinding
    on WorkspaceDirectConversationStateContext {
  @override
  Future<void> workspacePasteFromClipboard() {
    return executeWorkspaceDirectConversationStateWorkspacePasteFromClipboard();
  }
}

extension WorkspaceDirectConversationStateWorkspacePasteFromClipboardAction
    on WorkspaceDirectConversationStateContext {
  Future<void>
  executeWorkspaceDirectConversationStateWorkspacePasteFromClipboard() async {
    await workspaceAttachmentComposerKey.currentState?.pasteFromClipboard();
  }
}
