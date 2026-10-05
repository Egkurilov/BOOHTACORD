import '../../features/session/lifecycle/controller.dart';

import 'dart:async';

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

  Future<void> initialize() async {
    await session.initialize();
    if (!disposed) unawaited(guildProfile.refresh());
  }

  Future<void> setServer(String value) async {
    guildProfile.reset();
    await session.setServer(value);
    if (!disposed) unawaited(guildProfile.refresh());
  }

  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) => session.authenticate(login, password, register: register);

  Future<void> logout() => session.logout();
}
