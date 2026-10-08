import '../../../message_action_menu/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension MessageRowSenderMetadataRenderer on WorkspaceMessageRowContext {
  Row renderMessageRowSenderMetadata(String authorName, String time) => Row(
    children: [
      Expanded(
        child: Semantics(
          label: '$authorName, $time',
          child: const SizedBox.shrink(),
        ),
      ),
      if (!message.deleted && message.sendStatus == null)
        WorkspaceMessageActionMenu(
          message: message,
          canEdit: message.authorId == state.user?.accountId,
          canDelete:
              message.authorId == state.user?.accountId ||
              state.user?.isAdmin == true,
          onReply: onReply,
          mentionOptions: [
            for (final member in state.members) (member.id, member.displayName),
          ],
          selfId: state.user?.accountId ?? '',
          onEdit: (body, revision, ids) => state.editTextWithResult(
            message,
            body,
            revision,
            mentionUserIds: ids,
          ),
          onRefresh: () async {
            final latest = await state.refreshTextMessageRevision(message);
            return latest == null
                ? null
                : (revision: latest.revision, deleted: latest.deleted);
          },
          onDelete: () => state.deleteText(message),
        ),
    ],
  );
}
