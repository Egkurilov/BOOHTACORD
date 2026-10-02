import '../../features/session/reset_state/controller.dart';
import '../composition/owners.dart';

mixin AppResetAccess on AppOwners {
  bool get resetRoute => reset.resetRoute;

  set resetRoute(bool value) => reset.resetRoute = value;

  String? get resetToken => reset.resetToken;

  set resetToken(String? value) => reset.resetToken = value;

  bool get resetPending => reset.resetPending;

  set resetPending(bool value) => reset.resetPending = value;

  bool get resetCompleted => reset.resetCompleted;

  set resetCompleted(bool value) => reset.resetCompleted = value;

  bool get resetUnusable => reset.resetUnusable;

  set resetUnusable(bool value) => reset.resetUnusable = value;

  String? get resetError => reset.resetError;

  set resetError(String? value) => reset.resetError = value;

  bool get focusLoginOnMount => reset.focusLoginOnMount;

  set focusLoginOnMount(bool value) => reset.focusLoginOnMount = value;

  void openPasswordResetLink(String value) =>
      reset.openPasswordResetLink(value);

  Future<bool> completePasswordReset(String password) =>
      reset.completePasswordReset(password);

  void returnToLogin() => reset.returnToLogin();
}
