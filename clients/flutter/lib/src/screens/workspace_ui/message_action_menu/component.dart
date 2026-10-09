import '../confirm_delete/component.dart';
import '../edit_message_dialog/component.dart';
import '../native_bindings.dart';

class WorkspaceMessageActionMenu extends StatelessWidget {
  const WorkspaceMessageActionMenu({
    super.key,
    required this.message,
    required this.canEdit,
    required this.canDelete,
    required this.onReply,
    required this.mentionOptions,
    required this.selfId,
    required this.onEdit,
    required this.onRefresh,
    required this.onDelete,
  });

  final ChatMessage message;
  final bool canEdit;
  final bool canDelete;
  final ValueChanged<ChatMessage>? onReply;
  final List<(String, String)> mentionOptions;
  final String selfId;
  final Future<MessageEditOutcome> Function(String, int, List<String>) onEdit;
  final Future<({int revision, bool deleted})?> Function() onRefresh;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final mobile =
        MediaQuery.sizeOf(context).width < 1024 &&
        (platform == TargetPlatform.iOS || platform == TargetPlatform.android);
    final targetSize = mobile ? 48.0 : 40.0;
    return PopupMenuButton<String>(
      tooltip: 'Действия с сообщением',
      onSelected: (action) async {
        if (action == 'reply') {
          onReply?.call(message);
        } else if (action == 'edit') {
          await workspaceEditMessageDialog(
            context,
            message.body,
            message.revision,
            message.mentionUserIds,
            mentionOptions,
            selfId,
            onEdit,
            onRefresh,
          );
        } else if (action == 'delete' &&
            await workspaceConfirmDelete(context)) {
          await onDelete();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'reply', child: Text('Ответить')),
        if (canEdit)
          const PopupMenuItem(value: 'edit', child: Text('Изменить')),
        if (canDelete)
          const PopupMenuItem(value: 'delete', child: Text('Удалить')),
      ],
      style: ButtonStyle(
        tapTargetSize: mobile
            ? MaterialTapTargetSize.padded
            : MaterialTapTargetSize.shrinkWrap,
      ),
      child: Semantics(
        label: 'Действия с сообщением',
        button: true,
        child: SizedBox.square(
          dimension: targetSize,
          child: const Icon(Icons.more_horiz, size: 18),
        ),
      ),
    );
  }
}
