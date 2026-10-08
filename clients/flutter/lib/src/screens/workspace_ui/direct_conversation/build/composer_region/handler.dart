import '../compose_text/handler.dart';
import '../../../composer_keyboard_help/component.dart';
import '../../../mention_picker/component.dart';
import '../../../reply_target_banner/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension DirectConversationComposerRegionRenderer
    on WorkspaceDirectConversationStateContext {
  Container renderDirectConversationComposerRegion(
    bool compact,
    BorderRadius composerBorderRadius,
    bool compactComposerActions,
  ) => Container(
    key: const ValueKey('direct-message-composer-wrap'),
    constraints: BoxConstraints(
      minHeight: workspaceReplyTarget != null
          ? 131
          : compact
          ? 70
          : 98,
    ),
    padding: workspaceReplyTarget != null
        ? const EdgeInsets.fromLTRB(24, 0, 24, 18)
        : compact
        ? const EdgeInsets.all(8)
        : const EdgeInsets.fromLTRB(24, 8, 24, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (workspaceReplyTarget != null)
          WorkspaceReplyTargetBanner(
            text:
                'Ответ для ${workspaceDirectAuthorName(workspaceReplyTarget!.authorId)}',
            onCancel: () {
              workspaceMutateView(() => workspaceReplyTarget = null);
              workspaceRememberDraft();
            },
          ),
        WorkspaceMentionPicker(
          options: [
            (
              widget.conversation.participantId,
              widget.conversation.displayName,
            ),
          ],
          selfId: widget.state.user?.accountId ?? '',
          selectedIds: workspaceMentionUserIds,
          chipsOnly: true,
          onChanged: (ids) {
            workspaceMutateView(() {
              workspaceMentionUserIds
                ..clear()
                ..addAll(ids);
            });
            workspaceRememberDraft();
          },
        ),
        MessageAttachmentComposer(
          key: workspaceAttachmentComposerKey,
          state: widget.state,
          attachments: workspaceAttachments,
          textController: workspaceController,
          focusNode: workspaceComposerFocus,
          directMessageId: widget.conversation.id,
          onChanged: (attachments) {
            workspaceMutateView(() => workspaceAttachments = attachments);
            workspaceRememberDraft();
          },
          onPending: (pending) => workspaceMutateView(() {
            workspaceAttachmentsPending = pending;
          }),
        ),
        renderDirectConversationComposeText(
          compact,
          composerBorderRadius,
          compactComposerActions,
        ),
        WorkspaceComposerKeyboardHelp(compact: compact),
      ],
    ),
  );
}
