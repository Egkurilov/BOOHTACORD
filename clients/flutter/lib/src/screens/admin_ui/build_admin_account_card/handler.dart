import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminBuildAdminAccountCardBinding
    on AdminScreenStateContext {
  @override
  Widget adminBuildAdminAccountCard(AdminAccount account) =>
      executeAdminBuildAdminAccountCard(account);
}

extension AdminScreenStateAdminBuildAdminAccountCardBindingAction
    on AdminScreenStateContext {
  Widget executeAdminBuildAdminAccountCard(AdminAccount account) =>
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 720) {
            return adminBuildAdminAccountDesktopRow(account);
          }
          return adminBuildAdminAccountCompactCard(account);
        },
      );
}
