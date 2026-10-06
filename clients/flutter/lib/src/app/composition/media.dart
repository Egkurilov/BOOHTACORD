import '../../core/errors/presentation.dart';
import '../../features/audio/devices/controller.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/screen/lifecycle/controller.dart';
import 'owners.dart';

void configureMedia(AppOwners app) {
  app.audioDevices = AudioDeviceController(
    scope: app.session.scope,
    readRoom: () => app.voice.room,
    readAccountId: () => app.session.user?.accountId,
    loader: app.audioDeviceLoader,
    changes: app.audioDeviceChanges,
    nativeBootstrap: app.audioDeviceBootstrap,
  )..addListener(app.notifyListeners);
  app.screen = ScreenShareController(
    app.api,
    app.session.scope,
    readRoom: () => app.voice.room,
    voiceReady: () =>
        app.voice.voicePhase == VoicePhase.connected ||
        app.voice.voicePhase == VoicePhase.listener,
  )..addListener(app.notifyListeners);
  app.voice = VoiceController(
    app.api,
    app.session.scope,
    app.audioDevices,
    app.screen,
    readUser: () => app.session.user,
    reportError: (value) => app.error = value,
    formatError: appFailureMessage,
    roomFactory: app.voiceRoomFactory,
  )..addListener(app.notifyListeners);
}
