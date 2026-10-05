import 'dart:async';

import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';
import '../lifecycle/event.dart';
import '../../session/own_sessions/hint.dart';
import 'text_message.dart';

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
  final void Function(Map<String, dynamic>) voiceRevoked;
  final void Function() permissionsChanged;
  final void Function(int)? guildChanged;
  void call(RealtimeEvent event) {
    final payload = event.payload;
    switch (event.kind) {
      case 'guild.profile.updated':
        final revision = payload['revision'];
        if (payload.length == 1 && revision is int && revision > 0)
          guildChanged?.call(revision);
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
          unawaited(
            refreshTextEvent(
              conversation,
              workspace,
              payload['message_id'] as String?,
            ),
          );
        }
        notifyMessage(event);
      case 'direct_message.message_created':
        notifyMessage(event);
      case 'channel.updated':
        unawaited(workspace.refreshTopology());
      case 'role.permissions.updated':
      case 'auth.permissions.invalidated':
        permissionsChanged();
      case 'connection.ready':
        guildChanged?.call(0);
      case 'connection.resync_required':
        guildChanged?.call(0);
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
