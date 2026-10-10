import '../confirm_delete/component.dart';
import '../edit_message_dialog/component.dart';
import '../native_bindings.dart';
import '../message_action_menu/popup_button.dart';

class WorkspaceDirectMessageActionMenu extends StatelessWidget {
  const WorkspaceDirectMessageActionMenu({
    super.key,
    required this.message,
    required this.canEdit,
    required this.onReply,
    required this.mentionOptions,
    required this.selfId,
    required this.onEdit,
    required this.onRefresh,
    required this.onDelete,
  });

  final DirectChatMessage message;
  final bool canEdit;
  final ValueChanged<DirectChatMessage> onReply;
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
    return WorkspaceMessageActionPopupButton(
      mobile: mobile,
      items: [
        const PopupMenuItem(value: 'reply', child: Text('Ответить')),
        if (canEdit)
          const PopupMenuItem(value: 'edit', child: Text('Изменить')),
        if (canEdit)
          const PopupMenuItem(value: 'delete', child: Text('Удалить')),
      ],
      onSelected: (action) async {
        if (action == 'reply') {
          onReply(message);
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
    );
  }
}
