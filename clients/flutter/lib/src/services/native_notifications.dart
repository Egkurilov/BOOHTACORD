import '../features/notifications/lifecycle/controller.dart';
export '../features/notifications/lifecycle/controller.dart';
export '../features/notifications/platform/driver.dart';

// Retained import/type facade while callers move to the feature owner.
typedef NativeNotificationService = NotificationController;
