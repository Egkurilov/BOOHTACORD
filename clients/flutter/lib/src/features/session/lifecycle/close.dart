import 'controller.dart';

extension SessionTermination on SessionController {
  Future<void> logout() async {
    if (logoutBusy || !scope.capture().isCurrent) return;
    logoutBusy = true;
    logoutError = null;
    final ticket = scope.close();
    effects.invalidateOperations?.call();
    changed();
    if (closing) await waitForClose();
    if (!ticket.isCurrent) return;
    await closeWith(() async {
      try {
        await effects.closeMedia();
        await effects.closeRealtime();
        await api.logout();
      } catch (cause) {
        if (!ticket.isCurrent) return;
        logoutError = effects.message(cause);
        logoutBusy = false;
        scope.resume(ticket);
        try {
          await effects.resume?.call();
        } catch (_) {}
        changed();
        return;
      }
      if (!ticket.isCurrent) return;
      user = null;
      await effects.clearAccount();
      if (!ticket.isCurrent) return;
      phase = AppPhase.signedOut;
      logoutBusy = false;
      changed();
    });
  }

  Future<void> expire() async {
    if (closing) await waitForClose();
    if (phase != AppPhase.ready || !scope.capture().isCurrent) return;
    final ticket = scope.close();
    effects.invalidateOperations?.call();
    phase = AppPhase.signedOut;
    user = null;
    await closeWith(() async {
      await effects.expireAccount();
      if (!ticket.isCurrent) return;
      effects.error(null);
      changed();
    });
  }
}
