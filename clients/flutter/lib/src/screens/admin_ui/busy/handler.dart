import '../lifecycle/context.dart';

mixin AdminScreenStateAdminBusyBinding on AdminScreenStateContext {
  @override
  bool get adminBusy => executeAdminBusy;
}

extension AdminScreenStateAdminBusyBindingAction on AdminScreenStateContext {
  bool get executeAdminBusy => adminTopologyMutations.busy;
}
