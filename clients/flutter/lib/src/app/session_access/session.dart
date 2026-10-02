import '../../features/session/lifecycle/controller.dart';
import '../../models.dart';
import '../composition/owners.dart';

mixin AppSessionAccess on AppOwners {
  AppPhase get phase => session.phase;

  set phase(AppPhase value) => session.phase = value;

  SessionUser? get user => session.user;

  set user(SessionUser? value) => session.user = value;

  bool get logoutBusy => session.logoutBusy;

  set logoutBusy(bool value) => session.logoutBusy = value;

  String? get logoutError => session.logoutError;

  set logoutError(String? value) => session.logoutError = value;

  String get serverUrl => api.baseUrl;

  Future<void> initialize() => session.initialize();

  Future<void> setServer(String value) => session.setServer(value);

  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) => session.authenticate(login, password, register: register);

  Future<void> logout() => session.logout();
}
