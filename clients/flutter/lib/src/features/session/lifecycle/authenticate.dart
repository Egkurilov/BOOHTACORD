import 'controller.dart';

extension SessionAuthentication on SessionController {
  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) async {
    if (closing) await waitForClose();
    final ticket = scope.begin();
    if (!ticket.isActive) return;
    effects.error(null);
    changed();
    try {
      await api.authenticate(login, password, register: register);
      if (!ticket.isActive) return;
      final account = await api.currentSession();
      if (!ticket.isActive) return;
      user = account;
      if (account != null) await effects.prepare(account);
      if (!ticket.isActive) return;
      phase = AppPhase.ready;
      await effects.ready();
    } catch (cause) {
      if (!ticket.isActive) return;
      effects.error(effects.message(cause));
      rethrow;
    } finally {
      if (ticket.isActive) changed();
    }
  }
}
