import '../../../models.dart';
import '../../workspace/lifecycle/controller.dart';

int? addressedUnreadCount(
  WorkspaceController workspace,
  String? kind,
  Map<String, dynamic> payload,
) {
  if (kind == 'direct_message.message_created') {
    final id = payload['direct_message_id'];
    if (id is! String) return null;
    return workspace.directMessages
        .where((conversation) => conversation.id == id)
        .firstOrNull
        ?.unreadCount;
  }
  if (kind == 'message.created') {
    final id = payload['channel_id'];
    if (id is! String) return null;
    return workspace.topology?.categories
        .expand((category) => category.channels)
        .where(
          (channel) => channel.id == id && channel.kind == ChannelKind.text,
        )
        .firstOrNull
        ?.unreadCount;
  }
  return null;
}
