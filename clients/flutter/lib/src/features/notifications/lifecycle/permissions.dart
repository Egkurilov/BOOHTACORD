import 'controller.dart';

extension NotificationPermissions on NotificationController {
  Future<void> refreshStatus() async {
    if (!initialized || disposed) return;
    final account = accountScope.capture();
    try {
      final result = await driver.permission();
      if (!account.isCurrent) return;
      permission = result;
    } catch (cause) {
      if (!account.isCurrent) return;
      permission = NativeNotificationPermission.unavailable;
      error = notificationFailure(cause);
    }
    if (account.isCurrent) changed();
  }

  Future<bool> enable() async {
    final account = accountId;
    final active = admission();
    if (account == null || !initialized || !active()) return false;
    error = null;
    try {
      final result = permission == NativeNotificationPermission.granted
          ? permission
          : await driver.requestPermission();
      if (!active()) return false;
      permission = result;
      enabled = permission == NativeNotificationPermission.granted;
      await preferences.setBool(enabledKey(account), enabled);
      return active() && enabled;
    } catch (cause) {
      if (!active()) return false;
      error = notificationFailure(cause);
      enabled = false;
      return false;
    } finally {
      if (active()) changed();
    }
  }

  Future<void> disable() async {
    if (disposed) return;
    final account = accountId;
    enabled = false;
    error = null;
    changed();
    if (account != null) await preferences.setBool(enabledKey(account), false);
  }
}
