import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminCreateCategoryBinding on AdminScreenStateContext {
  @override
  Future<void> adminCreateCategory() => executeAdminCreateCategory();
}

extension AdminScreenStateAdminCreateCategoryBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminCreateCategory() async {
    final id = await adminTopologyMutations.actions.createCategory(
      adminCategoryName.text,
    );
    if (!mounted || id == null) return;
    adminCategoryName.clear();
    adminMutateView(() => adminCategoryId = id);
  }
}
