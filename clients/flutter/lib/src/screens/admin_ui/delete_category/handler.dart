import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminDeleteCategoryBinding on AdminScreenStateContext {
  @override
  Future<void> adminDeleteCategory(ChannelCategory category) =>
      executeAdminDeleteCategory(category);
}

extension AdminScreenStateAdminDeleteCategoryBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminDeleteCategory(ChannelCategory category) async {
    final revision = widget.state.topology?.revision;
    if (revision != null) {
      await adminTopologyMutations.actions.deleteCategory(category, revision);
    }
  }
}
