import '../native_bindings.dart';
import '../lifecycle/context.dart';
import '../account_draft/model.dart';

mixin AdminScreenStateAdminSaveAccountBinding on AdminScreenStateContext {
  @override
  Future<void> adminSaveAccount(AdminAccount account) =>
      executeAdminSaveAccount(account);
}

extension AdminScreenStateAdminSaveAccountBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminSaveAccount(AdminAccount account) async {
    final draft = adminAccountDrafts[account.accountId];
    if (draft == null || adminBusyAccountIds.contains(account.accountId)) {
      return;
    }
    if (account.updatedAt == null) {
      adminMutateView(
        () => adminAccountsError =
            'Обновите список участников: серверная версия аккаунта недоступна.',
      );
      return;
    }
    adminMutateView(() {
      adminBusyAccountIds.add(account.accountId);
      adminAccountsStatus = null;
      adminAccountsError = null;
    });
    try {
      await widget.state.api.updateAdminAccount(
        accountId: account.accountId,
        role: draft.role,
        blocked: draft.blocked,
        expectedUpdatedAt: account.updatedAt,
      );
      await adminLoadAccounts(acceptDrafts: true);
      if (mounted) {
        adminMutateView(
          () => adminAccountsStatus =
              'Изменения для @${account.login} сохранены.',
        );
      }
    } catch (cause) {
      if (cause is ApiFailure && cause.status == 409) {
        final conflict = adminAccountConflicts.putIfAbsent(
          account.accountId,
          () => AdminAccountConflict(before: account),
        );
        conflict.current = null;
        await adminLoadAccounts();
        if (mounted) {
          adminMutateView(
            () => adminAccountsError = 'Участник изменён другим администратором. Черновик сохранён; сравните данные и повторите действие.',
          );
        }
      } else if (mounted) {
        adminMutateView(() => adminAccountsError = cause.toString());
      }
    } finally {
      if (mounted) {
        adminMutateView(() => adminBusyAccountIds.remove(account.accountId));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final focusNode = adminAccountSaveFocusNodes[account.accountId];
          if (mounted && focusNode?.context != null) focusNode!.requestFocus();
        });
      }
    }
  }
}
