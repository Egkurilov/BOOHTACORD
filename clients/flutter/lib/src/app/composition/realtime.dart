import 'dart:async';

import '../../features/session/lifecycle/controller.dart';
import '../../features/realtime/lifecycle/controller.dart';
import '../../features/realtime/dispatch/workspace.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/notifications/message_events/controller.dart';
import 'owners.dart';

void configureRealtime(AppOwners app) {
  final notifications = MessageNotificationDispatch(
    app.session.scope,
    app.workspace,
    app.nativeNotifications,
    hasUser: () => app.session.user != null,
    isWelcome: (event) async {
      final page = await app.api.messagePage(
        event.payload['channel_id'] as String,
        at: event.payload['message_id'] as String,
      );
      return page.messages.any(
        (message) =>
            message.id == event.payload['message_id'] &&
            message.kind == 'SYSTEM_WELCOME' &&
            !message.deleted,
      );
    },
  );
  app.realtime = RealtimeController(
    app.api,
    app.session.scope,
    isReady: () => app.session.phase == AppPhase.ready,
    expire: app.session.expire,
    invalidatePresence: () => app.workspace.guildPresence.invalidate(),
    dispatch: WorkspaceRealtimeDispatch(
      app.workspace,
      app.conversation,
      voiceRevoked: app.voice.dispatchVoiceRevocation,
      permissionsChanged: () => unawaited(app.permissions.refresh()),
      notifyMessage: notifications.call,
      guildChanged: (revision) => unawaited(app.guildProfile.refresh(revision)),
    ).call,
  )..addListener(app.notifyListeners);
}
