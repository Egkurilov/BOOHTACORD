import 'controller.dart';

extension NotificationAccount on NotificationController {
  Future<void> useAccount(String? value) async {
    accountScope.begin();
    accountId = value;
    enabled = false;
    error = null;
    deliveriesInFlight.clear();
    changed();
    if (value == null || disposed) return;
    final active = admission();
    await initialize();
    if (!active() || !initialized) return;
    try {
      final stored = await preferences.getBool(enabledKey(value)) ?? false;
      if (!active()) return;
      enabled = stored;
      await refreshStatus();
    } catch (cause) {
      if (!active()) return;
      error = notificationFailure(cause);
      enabled = false;
    }
    if (active()) changed();
  }
}
