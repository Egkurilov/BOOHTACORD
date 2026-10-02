import '../../services/native_notifications.dart';
import '../../features/conversation/lifecycle/controller.dart';
import '../../features/realtime/lifecycle/controller.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/voice/preferences/clear.dart';
import '../../features/voice/roster_state/controller.dart';
import '../composition/owners.dart';

extension AppAccountCleanup on AppOwners {
  void clearPrivateCaches() {
    profileOwner.clear();
    workspace.clear();
    conversation.clear();
    voiceRoster.stop();
    voiceRoster.voiceRosters = null;
    voiceRoster.voiceRosterError = null;
    voice.clearAccountPreferences();
    audioDevices.clearAccount();
  }

  Future<void> clearSignedOutAccount() async {
    clearPrivateCaches();
    await nativeNotifications.useAccount(null);
  }

  Future<void> clearServerAccount() async {
    await clearSignedOutAccount();
    maintenance.restart();
  }

  Future<void> clearExpiredAccount() async {
    final ticket = session.scope.capture();
    final leaving = voice.leaveVoice();
    clearPrivateCaches();
    error = null;
    session.logoutError = null;
    realtime.eventIds.clear();
    notifyListeners();
    await Future.wait([
      leaving,
      realtime.close(),
      nativeNotifications.useAccount(null),
    ]);
    if (!ticket.isCurrent) return;
    error = null;
    notifyListeners();
  }
}
