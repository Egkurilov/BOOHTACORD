import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspacePasteFromClipboardBinding
    on WorkspaceConversationStateContext {
  @override
  Future<void> workspacePasteFromClipboard() {
    return executeWorkspaceConversationStateWorkspacePasteFromClipboard();
  }
}

extension WorkspaceConversationStateWorkspacePasteFromClipboardAction
    on WorkspaceConversationStateContext {
  Future<void>
  executeWorkspaceConversationStateWorkspacePasteFromClipboard() async {
    await workspaceAttachmentComposerKey.currentState?.pasteFromClipboard();
  }
}
