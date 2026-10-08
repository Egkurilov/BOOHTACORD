import '../lifecycle/context.dart';

mixin AdminScreenStateAdminStatusBinding on AdminScreenStateContext {
  @override
  String? get adminStatus => executeAdminStatus;
}

extension AdminScreenStateAdminStatusBindingAction on AdminScreenStateContext {
  String? get executeAdminStatus => adminTopologyMutations.status;
}
