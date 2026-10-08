import 'package:flutter/foundation.dart';
import '../../features/screen/preferences/store.dart';
import '../../features/screen/profile/quality.dart';
import '../../features/screen/lifecycle/controller.dart';
import '../composition/owners.dart';

extension AppScreenPreferences on AppOwners {
  ScreenQualityPreferences? captureScreenPreferences() {
    final accountId = session.user?.accountId;
    if (accountId == null) return null;
    final origin = api.baseUrl;
    final ticket = session.scope.capture();
    return ScreenQualityPreferences(origin, accountId, current: () =>
      !disposed && ticket.isActive && session.user?.accountId == accountId && api.baseUrl == origin);
  }

  Future<void> restoreScreenPreferences() async {
    final preferences = captureScreenPreferences();
    final stored = await preferences?.read();
    if (preferences?.isCurrent == true && stored != null && (screen.phase == ScreenSharePhase.idle || screen.phase == ScreenSharePhase.error)) {
      screen.quality = stored;
    }
  }

  void resetScreenPreference() {
    screen.quality = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS
      ? ScreenShareQuality.balanced : ScreenShareQuality.desktopDefault;
  }
}
