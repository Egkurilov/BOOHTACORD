import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceDirectConversationStateContext
    extends State<WorkspaceDirectConversation> {
  final workspaceController = TextEditingController();
  final workspaceComposerFocus = FocusNode();
  final workspaceAttachmentComposerKey =
      GlobalKey<MessageAttachmentComposerState>();
  final workspaceScroll = ScrollController();
  final Map<String, GlobalKey> workspaceDirectMessageKeys = {};
  DirectChatMessage? workspaceReplyTarget;
  final Set<String> workspaceMentionUserIds = {};
  List<MessageAttachment> workspaceAttachments = const [];
  bool workspaceAttachmentsPending = false;
  String? workspaceDraftAccountId;
  int workspaceDraftEpoch = 0;
  bool workspaceRestoringDraft = false;
  void workspaceRememberDraft();
  void workspaceRememberDraftFor(String conversationId);
  void workspaceRestoreDraft(String conversationId);
  Future<void> workspacePasteFromClipboard();
  Future<void> workspacePickMentions();
  Future<void> workspacePickEmoji();
  void workspaceInsertEmoji(String emoji);
  Future<void> workspaceLoadOlderDirect();
  List<({GlobalKey key, double top})> workspaceVisibleDirectMessageAnchors();
  Future<void> workspaceSend();
  Future<void> workspaceRetry(DirectChatMessage message);
  String workspaceDirectAuthorName(String accountId);
  String? workspaceDirectReplyLabel(DirectChatMessage message);
  void workspaceJumpToDirectReply(DirectChatMessage message);
  void workspaceReplyToDirect(DirectChatMessage message);
  void workspaceMutateView(VoidCallback action) => setState(action);
}
