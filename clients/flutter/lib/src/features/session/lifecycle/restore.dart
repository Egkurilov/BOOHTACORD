import 'dart:io';

import '../../../services/api_client.dart';
import 'controller.dart';

extension SessionRestoration on SessionController {
  Future<void> initialize() async {
    if (closing) await waitForClose();
    final ticket = scope.begin();
    if (!ticket.isActive) return;
    phase = AppPhase.loading;
    effects.error(null);
    changed();
    try {
      await api.initialize();
      if (!ticket.isActive) return;
      await effects.initialize();
      if (!ticket.isActive) return;
      final account = await api.currentSession().timeout(
        startupTimeout,
        onTimeout: () => throw ApiFailure(
          'Проверка сессии не завершилась вовремя. '
          '${Platform.isMacOS ? 'Проверьте системный запрос доступа к Связке ключей и соединение. ' : 'Проверьте соединение. '}'
          'Повторите попытку.',
        ),
      );
      if (!ticket.isActive) return;
      user = account;
      if (account == null) {
        await effects.clearAccount();
        if (!ticket.isActive) return;
        phase = AppPhase.signedOut;
      } else {
        await effects.prepare(account);
        if (!ticket.isActive) return;
        phase = AppPhase.ready;
        await effects.ready();
      }
    } catch (cause) {
      if (!ticket.isActive) return;
      phase = AppPhase.connectionError;
      effects.error(effects.message(cause));
    }
    if (ticket.isActive) changed();
  }
}
