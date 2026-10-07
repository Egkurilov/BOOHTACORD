import 'dart:async';

import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';
import '../lifecycle/event.dart';
import '../../session/own_sessions/hint.dart';
import '../../telemetry/realtime/process.dart';
import 'conversation_events.dart';
import 'screen_preview_event.dart';

class WorkspaceRealtimeDispatch {
  WorkspaceRealtimeDispatch(
    this.workspace,
    this.conversation, {
    required this.notifyMessage,
    required this.voiceRevoked,
    required this.permissionsChanged,
    this.guildChanged,
    this.screenPreviewUpdated,
    this.screenPreviewInvalidated,
  });
  final WorkspaceController workspace;
  final ConversationController conversation;
  final void Function(RealtimeEvent) notifyMessage;
  final FutureOr<void> Function(Map<String, dynamic>) voiceRevoked;
  final FutureOr<void> Function() permissionsChanged;
  final void Function(int)? guildChanged;
  final void Function(Map<String, dynamic>)? screenPreviewUpdated;
  final void Function(Map<String, dynamic>)? screenPreviewInvalidated;
  void call(RealtimeEvent event) {
    if (dispatchConversationEvent(event, workspace, conversation, notifyMessage)) return;
    if (dispatchScreenPreviewEvent(event, screenPreviewUpdated, screenPreviewInvalidated)) return;
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
