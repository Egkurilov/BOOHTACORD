import 'dart:async';

import '../../../core/session/scope.dart';
import '../../realtime/lifecycle/event.dart';
import '../../workspace/lifecycle/controller.dart';
import '../lifecycle/controller.dart';
import 'unread.dart';

class MessageNotificationDispatch {
  MessageNotificationDispatch(
    this.scope,
    this.workspace,
    this.notifications, {
    required this.hasUser,
  });
  final SessionScope scope;
  final WorkspaceController workspace;
  final NotificationController notifications;
  final bool Function() hasUser;
  void call(RealtimeEvent event) {
    final unread =
        addressedUnreadCount(workspace, event.kind, event.payload) ??
        (event.kind == 'direct_message.message_created' ? 0 : null);
    unawaited(deliver(event, unread));
  }

  Future<void> deliver(RealtimeEvent event, int? previousUnread) async {
    final ticket = scope.capture();
    if (!ticket.isActive || !hasUser() || event.kind == null) return;
    try {
      if (event.kind == 'message.created') {
        await workspace.refreshTopology();
      } else if (event.kind == 'direct_message.message_created') {
        await workspace.refreshDirectMessages();
      }
      if (!ticket.isActive) return;
      final body = notificationBodyForUnreadIncrease(
        kind: event.kind!,
        previousUnread: previousUnread,
        currentUnread:
            addressedUnreadCount(workspace, event.kind, event.payload) ??
            (event.kind == 'direct_message.message_created' ? 0 : null),
      );
      if (body == null) return;
      await notifications.deliver(
        eventId: event.id,
        body: body,
        appIsForeground: notifications.appIsForeground,
      );
    } catch (_) {
      // Native alerts must not interfere with message or realtime recovery.
    }
  }
}
