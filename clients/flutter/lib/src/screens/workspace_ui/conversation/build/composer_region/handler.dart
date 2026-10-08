import '../compose_text/handler.dart';
import '../../../composer_keyboard_help/component.dart';
import '../../../mention_display_name/component.dart';
import '../../../mention_picker/component.dart';
import '../../../reply_target_banner/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension ConversationComposerRegionRenderer
    on WorkspaceConversationStateContext {
  Container renderConversationComposerRegion(
    bool compact,
    double viewportWidth,
    BorderRadius composerBorderRadius,
    bool compactComposerActions,
  ) => Container(
    key: const ValueKey('text-composer-wrap'),
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
        : EdgeInsets.fromLTRB(
            viewportWidth < GcLayout.mediumBreakpoint ? 20 : 24,
            8,
            viewportWidth < GcLayout.mediumBreakpoint ? 20 : 24,
            16,
          ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (workspaceReplyTarget != null)
          WorkspaceReplyTargetBanner(
            text:
                'Ответ для ${workspaceMentionDisplayName(widget.state, workspaceReplyTarget!.authorId)}',
            onCancel: () {
              workspaceMutateView(() => workspaceReplyTarget = null);
              workspaceRememberDraft();
            },
          ),
        WorkspaceMentionPicker(
          options: widget.state.members
              .map((member) => (member.id, member.displayName))
              .toList(growable: false),
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
          channelId: widget.channel.id,
          textController: workspaceController,
          focusNode: workspaceComposerFocus,
          attachments: workspaceAttachments,
          onChanged: (attachments) {
            workspaceMutateView(() => workspaceAttachments = attachments);
            workspaceRememberDraft();
          },
          onPending: (pending) => workspaceMutateView(() {
            workspaceAttachmentsPending = pending;
          }),
          directMessageId: null,
        ),
        renderConversationComposeText(
          compact,
          composerBorderRadius,
          compactComposerActions,
        ),
        WorkspaceComposerKeyboardHelp(compact: compact),
      ],
    ),
  );
}
