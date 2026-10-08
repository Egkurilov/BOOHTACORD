import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceConversation extends StatefulWidget {
  const WorkspaceConversation({
    super.key,
    required this.state,
    required this.channel,
    this.onToggleNavigation,
    this.onOpenMembers,
  });
  final AppState state;
  final GuildChannel channel;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onOpenMembers;
  @override
  State<WorkspaceConversation> createState() => WorkspaceConversationState();
}

class WorkspaceConversationState extends WorkspaceConversationStateContext
    with
        WorkspaceConversationStateInitStateBinding,
        WorkspaceConversationStateWorkspaceRememberDraftBinding,
        WorkspaceConversationStateWorkspaceRestoreDraftBinding,
        WorkspaceConversationStateDidUpdateWidgetBinding,
        WorkspaceConversationStateWorkspaceRememberDraftForBinding,
        WorkspaceConversationStateWorkspaceOnScrollBinding,
        WorkspaceConversationStateWorkspaceScheduleVisibleReadBinding,
        WorkspaceConversationStateWorkspacePasteFromClipboardBinding,
        WorkspaceConversationStateWorkspacePickMentionsBinding,
        WorkspaceConversationStateWorkspacePickEmojiBinding,
        WorkspaceConversationStateWorkspaceInsertEmojiBinding,
        WorkspaceConversationStateDidChangeAppLifecycleStateBinding,
        WorkspaceConversationStateDisposeBinding,
        WorkspaceConversationStateWorkspaceSendBinding,
        WorkspaceConversationStateWorkspaceRetryBinding,
        WorkspaceConversationStateWorkspaceReplyToBinding,
        WorkspaceConversationStateWorkspaceLoadOlderBinding,
        WorkspaceConversationStateWorkspaceVisibleMessageAnchorsBinding,
        WorkspaceConversationStateWorkspaceJumpToReplyBinding,
        WorkspaceConversationStateWorkspaceReplyPreviewBinding,
        WorkspaceConversationStateBuildBinding {}
