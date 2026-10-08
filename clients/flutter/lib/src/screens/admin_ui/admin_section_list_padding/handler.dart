import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminAdminSectionListPaddingBinding
    on AdminScreenStateContext {
  @override
  EdgeInsets get adminSectionListPadding => executeAdminAdminSectionListPadding;
}

extension AdminScreenStateAdminAdminSectionListPaddingBindingAction
    on AdminScreenStateContext {
  EdgeInsets get executeAdminAdminSectionListPadding =>
      EdgeInsets.fromLTRB(adminContentInset, 0, adminContentInset, 24);
}
