import 'controller.dart';

extension SessionServerChange on SessionController {
  Future<void> setServer(String value) async {
    if (closing) await waitForClose();
    final ticket = scope.close();
    await closeWith(() async {
      try {
        effects.beforeServerChange();
        await effects.closeMedia();
        await effects.closeRealtime();
        await api.setBaseUrl(value);
        if (!ticket.isCurrent) return;
        user = null;
        await effects.clearServer();
        if (!ticket.isCurrent) return;
        phase = AppPhase.signedOut;
        effects.error(null);
        changed();
      } catch (_) {
        scope.resume(ticket);
        rethrow;
      }
    });
  }
}
