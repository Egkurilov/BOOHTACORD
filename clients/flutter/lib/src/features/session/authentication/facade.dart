import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AuthSessionFacade on ApiFacadeBase {
  late final _authSession = AuthSessionApi(transport);

  Future<SessionUser?> currentSession() => _authSession.currentSession();

  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) => _authSession.authenticate(login, password, register: register);

  Future<void> logout() => _authSession.logout();
}
