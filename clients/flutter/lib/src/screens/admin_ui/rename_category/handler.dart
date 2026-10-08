import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminRenameCategoryBinding on AdminScreenStateContext {
  @override
  Future<void> adminRenameCategory(ChannelCategory category) =>
      executeAdminRenameCategory(category);
}

extension AdminScreenStateAdminRenameCategoryBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminRenameCategory(ChannelCategory category) async {
    final revision = widget.state.topology?.revision;
    if (revision != null) {
      await adminTopologyMutations.actions.renameCategory(
        category,
        revision,
        adminCategoryRename.text,
      );
    }
  }
}
