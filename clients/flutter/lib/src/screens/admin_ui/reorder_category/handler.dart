import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminReorderCategoryBinding on AdminScreenStateContext {
  @override
  Future<void> adminReorderCategory(int direction) =>
      executeAdminReorderCategory(direction);
}

extension AdminScreenStateAdminReorderCategoryBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminReorderCategory(int direction) async {
    final topology = widget.state.topology;
    if (topology == null || adminCategoryId == null) return;
    await adminTopologyMutations.actions.reorderCategory(
      adminCategoryId!,
      topology.revision,
      direction,
    );
  }
}
