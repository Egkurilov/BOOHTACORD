import '../lifecycle/context.dart';

mixin AdminScreenStateAdminErrorBinding on AdminScreenStateContext {
  @override
  String? get adminError => executeAdminError;
}

extension AdminScreenStateAdminErrorBindingAction on AdminScreenStateContext {
  String? get executeAdminError => adminTopologyMutations.error;
}
