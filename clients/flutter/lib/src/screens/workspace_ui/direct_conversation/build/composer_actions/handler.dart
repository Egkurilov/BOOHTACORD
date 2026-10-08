import '../../../mention_picker/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension DirectConversationComposerActionsRenderer
    on WorkspaceDirectConversationStateContext {
  Row renderDirectConversationComposerActions(
    bool compactComposerActions,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: compactComposerActions
        ? [
            CompactMessageComposerActions(
              enabled: !widget.state.sending && !workspaceAttachmentsPending,
              onAttach: () =>
                  workspaceAttachmentComposerKey.currentState?.pickFiles(),
              onPaste: workspacePasteFromClipboard,
              onMention: workspacePickMentions,
              onEmoji: workspacePickEmoji,
            ),
          ]
        : [
            PopupMenuButton<String>(
              tooltip: 'Вложение и вставка',
              enabled: !widget.state.sending && !workspaceAttachmentsPending,
              onSelected: (action) {
                if (action == 'file') {
                  workspaceAttachmentComposerKey.currentState?.pickFiles();
                } else if (action == 'paste') {
                  workspacePasteFromClipboard();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'file',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.attach_file),
                    title: Text('Прикрепить файл'),
                  ),
                ),
                PopupMenuItem(
                  value: 'paste',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.content_paste),
                    title: Text('Вставить из буфера'),
                  ),
                ),
              ],
              child: const SizedBox(
                width: 44,
                height: 48,
                child: Icon(Icons.add_circle_outline),
              ),
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
              triggerOnly: true,
              disabled: widget.state.sending,
              onChanged: (ids) {
                workspaceMutateView(() {
                  workspaceMentionUserIds
                    ..clear()
                    ..addAll(ids);
                });
                workspaceRememberDraft();
              },
            ),
            MessageEmojiPickerButton(
              enabled: !widget.state.sending,
              onSelected: workspaceInsertEmoji,
            ),
          ],
  );
}
