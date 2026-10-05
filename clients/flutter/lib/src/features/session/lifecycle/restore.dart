import 'dart:io';

import '../../../services/api_client.dart';
import 'controller.dart';

extension SessionRestoration on SessionController {
  Future<void> initialize() async {
    if (closing) await waitForClose();
    final previousUser = user;
    final ticket = scope.begin();
    if (!ticket.isActive) return;
    phase = AppPhase.loading;
    effects.error(null);
    changed();
    try {
      final account =
          await (() async {
            await api.initialize();
            if (!ticket.isActive) return null;
            await effects.initialize();
            if (!ticket.isActive) return null;
            final account = await api.currentSession();
            if (!ticket.isActive) return null;
            if (account == null) {
              await effects.clearAccount();
            } else {
              // Account-scoped preparations (audio preferences, notifications,
              // and other local state) read the current account through this
              // controller. Publish the restored account before preparing it,
              // matching the interactive authentication flow.
              user = account;
              await effects.prepare(account);
            }
            return account;
          })().timeout(
            startupTimeout,
            onTimeout: () => throw ApiFailure(
              'Подключение не завершилось вовремя. '
              '${Platform.isMacOS ? 'Проверьте системный запрос доступа к Связке ключей и соединение. ' : 'Проверьте соединение. '}'
              'Повторите попытку.',
            ),
          );
      if (!ticket.isActive) return;
      user = account;
      if (account == null) {
        phase = AppPhase.signedOut;
      } else {
        phase = AppPhase.ready;
        await effects.ready();
      }
    } catch (cause) {
      if (!ticket.isActive) return;
      user = previousUser;
      phase = AppPhase.connectionError;
      effects.error(effects.message(cause));
    }
    if (ticket.isActive) changed();
  }
}
