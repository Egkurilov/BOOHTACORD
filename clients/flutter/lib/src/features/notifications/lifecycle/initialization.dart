import 'controller.dart';

extension NotificationInitialization on NotificationController {
  Future<void> initialize() async {
    if (disposed || !supported || initialized) return;
    if (initializing != null) return initializing;
    final operation = _initialize();
    initializing = operation;
    try {
      await operation;
    } finally {
      initializing = null;
    }
  }

  Future<void> _initialize() async {
    try {
      await driver.initialize();
      if (disposed) return;
      initialized = true;
      await refreshStatus();
    } catch (cause) {
      if (disposed) return;
      error = notificationFailure(cause);
      permission = NativeNotificationPermission.unavailable;
      changed();
    }
  }
}
