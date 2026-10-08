import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminAdminContentInsetBinding on AdminScreenStateContext {
  @override
  double get adminContentInset => executeAdminAdminContentInset;
}

extension AdminScreenStateAdminAdminContentInsetBindingAction
    on AdminScreenStateContext {
  double get executeAdminAdminContentInset =>
      adminWidthClassFor(MediaQuery.sizeOf(context).width).isCompact ? 0 : 24;
}
