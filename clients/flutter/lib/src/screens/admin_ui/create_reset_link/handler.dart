import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminCreateResetLinkBinding on AdminScreenStateContext {
  @override
  Future<void> adminCreateResetLink(AdminAccount account) =>
      executeAdminCreateResetLink(account);
}

extension AdminScreenStateAdminCreateResetLinkBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminCreateResetLink(AdminAccount account) async {
    adminMutateView(() {
      adminResetLink = null;
      adminResetLogin = null;
      adminBusyAccountIds.add(account.accountId);
      adminAccountsError = null;
    });
    try {
      final result = await widget.state.api.createAdminPasswordResetLink(
        account.accountId,
      );
      if (mounted) {
        adminMutateView(() {
          adminResetLink = result;
          adminResetLogin = account.login;
        });
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
