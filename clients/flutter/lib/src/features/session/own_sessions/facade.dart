import '../../../core/http/facade_base.dart';
import 'api.dart';
import 'model.dart';

mixin OwnSessionsFacade on ApiFacadeBase {
  late final _ownSessions = OwnSessionsApi(transport);
  Future<OwnSessionPage> ownSessions([String? cursor]) =>
      transport.run(() => _ownSessions.read(cursor));
  Future<void> revokeOwnSession(String owner, String id) =>
      transport.run(() => _ownSessions.revoke(owner, id));
  Future<void> revokeOtherSessions(String owner) =>
      transport.run(() => _ownSessions.revokeOthers(owner));
}
