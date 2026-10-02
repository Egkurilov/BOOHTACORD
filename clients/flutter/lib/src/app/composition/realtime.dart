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
      notifyMessage: notifications.call,
    ).call,
  )..addListener(app.notifyListeners);
}
