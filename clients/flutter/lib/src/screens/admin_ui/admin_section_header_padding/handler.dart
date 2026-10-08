import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminAdminSectionHeaderPaddingBinding
    on AdminScreenStateContext {
  @override
  EdgeInsets get adminSectionHeaderPadding =>
      executeAdminAdminSectionHeaderPadding;
}

extension AdminScreenStateAdminAdminSectionHeaderPaddingBindingAction
    on AdminScreenStateContext {
  EdgeInsets get executeAdminAdminSectionHeaderPadding =>
      EdgeInsets.fromLTRB(adminContentInset, 0, adminContentInset, 12);
}
