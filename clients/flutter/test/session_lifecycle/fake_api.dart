import 'dart:async';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class SessionFakeApi extends ApiClient {
  Completer<SessionUser?>? restore;
  Completer<void>? leaving;
  bool failLogout = false;
  int authentications = 0;
  void Function()? loggingOut;
  @override
  Future<void> initialize() async {}
  @override
  Future<SessionUser?> currentSession() async => restore == null
      ? const SessionUser(accountId: 'account', role: 'MEMBER')
      : restore!.future;
  @override
  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) async {
    authentications++;
  }

  @override
  Future<void> logout() async {
    loggingOut?.call();
    await leaving?.future;
    if (failLogout) throw const ApiFailure('logout failed');
  }
}
