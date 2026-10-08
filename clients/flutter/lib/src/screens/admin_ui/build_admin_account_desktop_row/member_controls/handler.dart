import '../actions/handler.dart';
import '../../native_bindings.dart';
import '../../lifecycle/context.dart';
import '../../account_draft/model.dart';

extension RenderAdminMemberControlsAction on AdminScreenStateContext {
  List<Widget> renderAdminMemberControls(
    AdminAccount account,
    AdminAccountDraft? draft,
    bool busy,
    bool sameVoiceParticipant,
  ) => [
    Expanded(
      flex: 3,
      child: DropdownButtonFormField<String>(
        key: ValueKey('role:${account.accountId}:${draft?.role}'),
        initialValue: draft?.role,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        items: const [
          DropdownMenuItem(value: 'MEMBER', child: Text('Участник')),
          DropdownMenuItem(
            value: 'ADMINISTRATOR',
            child: Text('Администратор'),
          ),
        ],
        onChanged: busy || draft == null
            ? null
            : (value) {
                if (value != null) adminMutateView(() => draft.role = value);
              },
      ),
    ),
    Switch(
      value: draft?.blocked ?? account.blocked,
      onChanged: busy || draft == null
          ? null
          : (value) => adminMutateView(() => draft.blocked = value),
    ),
    adminAccessBadge(draft?.blocked ?? account.blocked),
    const SizedBox(width: 4),
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
    const SizedBox(width: 4),
    TextButton(
      key: ValueKey('reset-account:${account.accountId}'),
      onPressed: busy ? null : () => adminCreateResetLink(account),
      child: const Text('Сбросить пароль'),
    ),
    renderAdminMemberActions(account, busy, draft, sameVoiceParticipant),
  ];
}
