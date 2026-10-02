import '../../../services/api_client.dart';
import 'controller.dart';

extension PasswordResetCompletion on PasswordResetController {
  Future<bool> completePasswordReset(String password) async {
    final token = resetToken;
    if (disposed ||
        !resetRoute ||
        token == null ||
        resetPending ||
        resetUnusable) {
      return false;
    }
    final expected = revision;
    final session = api.transport.session;
    final ticket = session.scope.capture();
    final server = session.serverRevision;
    bool current() =>
        !disposed &&
        expected == revision &&
        ticket.isCurrent &&
        server == session.serverRevision;
    resetPending = true;
    resetError = null;
    changed();
    try {
      await api.completePasswordReset(token, password);
      if (!current()) return false;
      resetToken = null;
      resetCompleted = true;
      return true;
    } catch (cause) {
      if (!current()) return false;
      resetError = message(cause);
      if (cause is ApiFailure && cause.status == 400) {
        resetToken = null;
        resetUnusable = true;
      }
      return false;
    } finally {
      if (current()) {
        resetPending = false;
        changed();
      }
    }
  }
}
