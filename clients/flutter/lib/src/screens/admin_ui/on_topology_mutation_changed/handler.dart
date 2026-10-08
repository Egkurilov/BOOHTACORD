import '../lifecycle/context.dart';

mixin AdminScreenStateAdminOnTopologyMutationChangedBinding
    on AdminScreenStateContext {
  @override
  void adminOnTopologyMutationChanged() {
    executeAdminOnTopologyMutationChanged();
  }
}

extension AdminScreenStateAdminOnTopologyMutationChangedBindingAction
    on AdminScreenStateContext {
  void executeAdminOnTopologyMutationChanged() {
    if (mounted) adminMutateView(() {});
  }
}
