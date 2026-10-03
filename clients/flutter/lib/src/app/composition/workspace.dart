import 'dart:async';

import '../../core/errors/presentation.dart';
import '../../features/session/lifecycle/controller.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../../features/conversation/lifecycle/controller.dart';
import '../../features/profile/state/controller.dart';
import '../../features/voice/roster_state/controller.dart';
import '../../features/authorization/permissions/controller.dart';
import 'owners.dart';

void configureWorkspace(AppOwners app) {
  app.permissions = PermissionController(app.api, app.session.scope)
    ..addListener(app.notifyListeners);
  app.workspace = WorkspaceController(
    app.api,
    app.session.scope,
    effects: WorkspaceEffects(
      audioPanelOpened: () {
        app.audioDevices.watch();
        unawaited(app.audioDevices.refreshAudioDevices());
      },
      selectChannel: (channel) => app.conversation.loadChannelHistory(channel),
      openDirect: (direct) => app.conversation.loadDirectHistory(direct),
      invalidateText: () => app.conversation.invalidateSelection(),
      clearText: () => app.conversation.clearText(),
      clearDirect: () => app.conversation.clearDirect(),
      error: (value) => app.error = value,
      message: appFailureMessage,
    ),
  )..addListener(app.notifyListeners);
  app.conversation = ConversationController(
    app.api,
    app.session.scope,
    app.workspace,
    readUser: () => app.session.user,
    isReady: () => app.session.phase == AppPhase.ready,
    reportError: (value) => app.error = value,
    formatError: appFailureMessage,
  )..addListener(app.notifyListeners);
  app.profileOwner = ProfileController(
    app.api,
    app.session.scope,
    error: (value) => app.error = value,
    formatError: appFailureMessage,
    refreshMembers: app.workspace.refreshMembers,
  )..addListener(app.notifyListeners);
  app.voiceRoster = VoiceRosterController(
    app.api,
    app.session.scope,
    isReady: () => app.session.phase == AppPhase.ready,
    hasUser: () => app.session.user != null,
    message: appFailureMessage,
    retryDelay: app.voiceRosterRetryDelay,
    staleTimeout: app.voiceRosterStaleTimeout,
  )..addListener(app.notifyListeners);
}
