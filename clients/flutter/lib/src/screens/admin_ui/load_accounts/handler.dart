import '../native_bindings.dart';
import '../lifecycle/context.dart';
import '../account_draft/model.dart';

mixin AdminScreenStateAdminLoadAccountsBinding on AdminScreenStateContext {
  @override
  Future<void> adminLoadAccounts({String? cursor, bool acceptDrafts = false}) =>
      executeAdminLoadAccounts(cursor: cursor, acceptDrafts: acceptDrafts);
}

extension AdminScreenStateAdminLoadAccountsBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminLoadAccounts({
    String? cursor,
    bool acceptDrafts = false,
  }) async {
    if (adminAccountsLoading) return;
    adminMutateView(() {
      adminAccountsLoading = true;
      adminAccountsError = null;
    });
    try {
      final page = await widget.state.api.listAdminAccounts(cursor: cursor);
      if (!mounted) return;
      adminMutateView(() {
        adminAccounts = cursor == null
            ? page.accounts
            : [...adminAccounts, ...page.accounts];
        adminAccountCursor = page.nextCursor;
        for (final account in page.accounts) {
          final baseline = adminAccountBaselines[account.accountId];
          final draft = adminAccountDrafts[account.accountId];
          if (baseline == null || acceptDrafts) {
            adminAccountBaselines[account.accountId] = account;
            adminAccountDrafts[account.accountId] = AdminAccountDraft(
              role: account.role,
              blocked: account.blocked,
            );
            adminAccountConflicts.remove(account.accountId);
            continue;
          }
          if (draft == null || !adminDraftChanged(baseline, draft)) {
            adminAccountBaselines[account.accountId] = account;
            adminAccountDrafts[account.accountId] = AdminAccountDraft(
              role: account.role,
              blocked: account.blocked,
            );
          } else if (baseline.updatedAt != account.updatedAt) {
            final conflict = adminAccountConflicts.putIfAbsent(
              account.accountId,
              () => AdminAccountConflict(before: baseline),
            );
            conflict.current = account;
          } else if (adminAccountConflicts[account.accountId]
              case final conflict?) {
            conflict.current = account;
          }
        }
      });
    } catch (cause) {
      if (mounted) adminMutateView(() => adminAccountsError = cause.toString());
    } finally {
      if (mounted) adminMutateView(() => adminAccountsLoading = false);
    }
  }
}
