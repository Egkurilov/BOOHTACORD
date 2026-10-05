import 'dart:async';

import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';
import '../lifecycle/event.dart';
import '../../session/own_sessions/hint.dart';

class WorkspaceRealtimeDispatch {
  WorkspaceRealtimeDispatch(
    this.workspace,
    this.conversation, {
    required this.notifyMessage,
    required this.voiceRevoked,
    required this.permissionsChanged,
  });
  final WorkspaceController workspace;
  final ConversationController conversation;
  final void Function(RealtimeEvent) notifyMessage;
  final void Function(Map<String, dynamic>) voiceRevoked;
  final void Function() permissionsChanged;
  void call(RealtimeEvent event) {
    final payload = event.payload;
    switch (event.kind) {
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
        if (workspace.selectedChannel?.id == payload['channel_id']) {
          unawaited(conversation.refreshSelectedTextHistory());
        }
        notifyMessage(event);
      case 'direct_message.message_created':
        notifyMessage(event);
      case 'channel.updated':
        unawaited(workspace.refreshTopology());
      case 'role.permissions.updated':
      case 'auth.permissions.invalidated':
        permissionsChanged();
      case 'connection.resync_required':
        unawaited(workspace.refreshTopology());
        unawaited(workspace.refreshMembers());
        if (workspace.selectedChannel?.kind == ChannelKind.text) {
          unawaited(conversation.refreshSelectedTextHistory());
        }
      case 'voice.lease_revoked':
        voiceRevoked(payload);
    }
  }
}
