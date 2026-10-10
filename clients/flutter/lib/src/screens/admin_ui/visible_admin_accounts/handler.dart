import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminVisibleAdminAccountsBinding
    on AdminScreenStateContext {
  @override
  List<AdminAccount> get adminVisibleAdminAccounts =>
      executeAdminVisibleAdminAccounts;
}

extension AdminScreenStateAdminVisibleAdminAccountsBindingAction
    on AdminScreenStateContext {
  List<AdminAccount> get executeAdminVisibleAdminAccounts => filterAdminMembers(
    adminAccounts,
    search: adminAccountSearch.text,
    role: adminAccountRoleFilter,
    status: adminAccountStatusFilter,
  );
}
