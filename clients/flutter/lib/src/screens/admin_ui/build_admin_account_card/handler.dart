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
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          if (constraints.maxWidth / scale >= 720) {
            return adminBuildAdminAccountDesktopRow(account);
          }
          return adminBuildAdminAccountCompactCard(account);
        },
      );
}
