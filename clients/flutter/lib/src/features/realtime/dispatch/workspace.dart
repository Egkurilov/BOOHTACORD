import 'dart:async';

import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';
import '../lifecycle/event.dart';
import '../../session/own_sessions/hint.dart';
import 'text_message.dart';
import 'direct_message.dart';
import '../../telemetry/realtime/process.dart';

class WorkspaceRealtimeDispatch {
  WorkspaceRealtimeDispatch(
    this.workspace,
    this.conversation, {
    required this.notifyMessage,
    required this.voiceRevoked,
    required this.permissionsChanged,
    this.guildChanged,
  });
  final WorkspaceController workspace;
  final ConversationController conversation;
  final void Function(RealtimeEvent) notifyMessage;
  final FutureOr<void> Function(Map<String, dynamic>) voiceRevoked;
  final FutureOr<void> Function() permissionsChanged;
  final void Function(int)? guildChanged;
  void call(RealtimeEvent event) {
    final payload = event.payload;
    switch (event.kind) {
      case 'guild.profile.updated':
        final revision = payload['revision'];
        if (payload.length == 1 && revision is int && revision > 0) {
          guildChanged?.call(revision);
        }
      case 'session.state_changed':
        if (payload.isEmpty) notifyOwnSessionsChanged();
      case 'presence.snapshot':
        workspace.guildPresence.acceptSnapshot(payload['online_user_ids']);
      case 'presence.changed':
        workspace.guildPresence.acceptChange(
          payload['user_id'],
          payload['presence'],
        );
      case 'message.created':
      case 'message.updated':
      case 'message.deleted':
        if (workspace.selectedChannel?.id == payload['channel_id']) {
          unawaited(
            refreshReceived(
              event,
              conversation.api.transport.session.telemetry,
              () => refreshTextEvent(
                conversation,
                workspace,
                payload['message_id'] as String?,
              ),
              () => conversation.messages
                  .map((m) => (id: m.id, value: m as Object))
                  .toList(),
            ),
          );
        }
        if (event.kind == 'message.created') notifyMessage(event);
      case 'direct_message.message_created':
      case 'direct_message.message_updated':
      case 'direct_message.message_deleted':
        if (conversation.selectedDirectMessage?.id ==
            payload['direct_message_id']) {
          unawaited(
            refreshReceived(
              event,
              conversation.api.transport.session.telemetry,
              () => refreshDirectEvent(
                conversation,
                payload['message_id'] as String?,
              ),
              () => conversation.directMessageHistory
                  .map((m) => (id: m.id, value: m as Object))
                  .toList(),
            ),
          );
        }
        if (event.kind == 'direct_message.message_created') {
          notifyMessage(event);
        }
      case 'channel.updated':
        unawaited(
          processEffect(
            event,
            conversation.api.transport.session.telemetry,
            workspace.refreshTopology,
          ),
        );
      case 'role.permissions.updated':
      case 'auth.permissions.invalidated':
        unawaited(
          processEffect(
            event,
            conversation.api.transport.session.telemetry,
            () => Future<void>.sync(permissionsChanged),
          ),
        );
      case 'connection.ready':
        guildChanged?.call(0);
      case 'connection.resync_required':
        guildChanged?.call(0);
        unawaited(
          processEffect(
            event,
            conversation.api.transport.session.telemetry,
            () => Future.wait([
              workspace.refreshTopology(),
              workspace.refreshMembers(),
              if (workspace.selectedChannel?.kind == ChannelKind.text)
                conversation.refreshSelectedTextHistory(),
              if (conversation.selectedDirectMessage != null)
                refreshDirectEvent(conversation),
            ]).then((_) {}),
          ),
        );
      case 'voice.lease_revoked':
        unawaited(
          processEffect(
            event,
            conversation.api.transport.session.telemetry,
            () => Future<void>.sync(() => voiceRevoked(payload)),
          ),
        );
    }
  }
}
