import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension AdminCompactActions on AdminScreenStateContext {
  Widget renderAdminCompactActions(
    AdminAccount account,
    bool busy,
    bool sameVoiceParticipant,
  ) => Wrap(
    spacing: 8,
    children: [
      FilledButton.tonal(
        key: ValueKey('save-account:${account.accountId}'),
        focusNode: adminAccountSaveFocusNodes.putIfAbsent(
          account.accountId,
          FocusNode.new,
        ),
        onPressed: busy ? null : () => adminSaveAccount(account),
        child: busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Сохранить'),
      ),
      OutlinedButton(
        key: ValueKey('reset-account:${account.accountId}'),
        onPressed: busy ? null : () => adminCreateResetLink(account),
        child: const Text('Сбросить пароль'),
      ),
      if (sameVoiceParticipant &&
          account.accountId != widget.state.user?.accountId)
        OutlinedButton(
          onPressed: busy ? null : () => adminKickVoiceParticipant(account),
          child: const Text('Отключить от голоса'),
        ),
    ],
  );
}
