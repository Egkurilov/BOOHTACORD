import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceDirectConversation extends StatefulWidget {
  const WorkspaceDirectConversation({
    super.key,
    required this.state,
    required this.conversation,
    this.onToggleNavigation,
    this.onOpenMembers,
  });
  final AppState state;
  final DirectConversation conversation;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onOpenMembers;

  @override
  State<WorkspaceDirectConversation> createState() =>
      WorkspaceDirectConversationState();
}

class WorkspaceDirectConversationState
    extends WorkspaceDirectConversationStateContext
    with
        WorkspaceDirectConversationStateInitStateBinding,
        WorkspaceDirectConversationStateWorkspaceRememberDraftBinding,
        WorkspaceDirectConversationStateWorkspaceRememberDraftForBinding,
        WorkspaceDirectConversationStateWorkspaceRestoreDraftBinding,
        WorkspaceDirectConversationStateWorkspacePasteFromClipboardBinding,
        WorkspaceDirectConversationStateWorkspacePickMentionsBinding,
        WorkspaceDirectConversationStateWorkspacePickEmojiBinding,
        WorkspaceDirectConversationStateWorkspaceInsertEmojiBinding,
        WorkspaceDirectConversationStateDidUpdateWidgetBinding,
        WorkspaceDirectConversationStateDisposeBinding,
        WorkspaceDirectConversationStateWorkspaceLoadOlderDirectBinding,
        WorkspaceDirectConversationStateWorkspaceVisibleDirectMessageAnchorsBinding,
        WorkspaceDirectConversationStateWorkspaceSendBinding,
        WorkspaceDirectConversationStateWorkspaceRetryBinding,
        WorkspaceDirectConversationStateWorkspaceDirectAuthorNameBinding,
        WorkspaceDirectConversationStateWorkspaceDirectReplyLabelBinding,
        WorkspaceDirectConversationStateWorkspaceJumpToDirectReplyBinding,
        WorkspaceDirectConversationStateWorkspaceReplyToDirectBinding,
        WorkspaceDirectConversationStateBuildBinding {}
