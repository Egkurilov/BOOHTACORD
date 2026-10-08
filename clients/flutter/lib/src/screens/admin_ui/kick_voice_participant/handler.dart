import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminKickVoiceParticipantBinding
    on AdminScreenStateContext {
  @override
  Future<void> adminKickVoiceParticipant(AdminAccount account) =>
      executeAdminKickVoiceParticipant(account);
}

extension AdminScreenStateAdminKickVoiceParticipantBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminKickVoiceParticipant(AdminAccount account) async {
    if (adminBusyAccountIds.contains(account.accountId)) return;
    final confirmed = await showConfirmationDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отключить от голоса?'),
        content: const Text('Отключить участника от голосового канала?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    adminMutateView(() {
      adminBusyAccountIds.add(account.accountId);
      adminAccountsStatus = null;
      adminAccountsError = null;
    });
    try {
      final revoked = await widget.state.api.kickAdminVoiceParticipant(
        account.accountId,
      );
      if (mounted) {
        adminMutateView(
          () => adminAccountsStatus = revoked > 0
              ? 'Подключение отозвано.'
              : 'Активное голосовое подключение не найдено.',
        );
      }
    } catch (cause) {
      if (mounted) adminMutateView(() => adminAccountsError = cause.toString());
    } finally {
      if (mounted) {
        adminMutateView(() => adminBusyAccountIds.remove(account.accountId));
      }
    }
  }
}
