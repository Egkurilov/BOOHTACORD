import '../native_bindings.dart';
import '../lifecycle/context.dart';
import '../account_draft/model.dart';

mixin AdminScreenStateAdminBuildAccountConflictCardBinding
    on AdminScreenStateContext {
  @override
  Widget adminBuildAccountConflictCard(
    String accountId,
    AdminAccountConflict conflict,
  ) => executeAdminBuildAccountConflictCard(accountId, conflict);
}

extension AdminScreenStateAdminBuildAccountConflictCardBindingAction
    on AdminScreenStateContext {
  Widget executeAdminBuildAccountConflictCard(
    String accountId,
    AdminAccountConflict conflict,
  ) {
    final account = adminAccounts
        .where((item) => item.accountId == accountId)
        .firstOrNull;
    final draft = adminAccountDrafts[accountId];
    if (account == null || draft == null) return const SizedBox.shrink();
    return AdminMemberConflictReview(
      login: account.login,
      before: adminAccountSummary(
        conflict.before.role,
        conflict.before.blocked,
      ),
      current: conflict.current == null
          ? null
          : adminAccountSummary(
              conflict.current!.role,
              conflict.current!.blocked,
            ),
      proposed: adminAccountSummary(draft.role, draft.blocked),
      busy: adminBusyAccountIds.contains(accountId) || adminAccountsLoading,
      onRefresh: adminLoadAccounts,
      onDiscard: () => adminMutateView(() {
        final current = conflict.current;
        if (current == null) return;
        adminAccountBaselines[accountId] = current;
        adminAccountDrafts[accountId] = AdminAccountDraft(
          role: current.role,
          blocked: current.blocked,
        );
        adminAccountConflicts.remove(accountId);
        adminAccountsStatus = 'Приняты актуальные данные @$account.login.';
      }),
      onApply: () => adminMutateView(() {
        final current = conflict.current;
        if (current == null) return;
        adminAccountBaselines[accountId] = current;
        adminAccountConflicts.remove(accountId);
        adminAccountsStatus =
            'Сравнение @${account.login} подтверждено. Нажмите «Сохранить».';
      }),
    );
  }
}
