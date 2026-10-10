import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminCreateChannelBinding on AdminScreenStateContext {
  @override
  Future<void> adminCreateChannel() => executeAdminCreateChannel();
}

extension AdminScreenStateAdminCreateChannelBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminCreateChannel() async {
    final categoryId =
        adminCategoryId ?? widget.state.topology?.categories.firstOrNull?.id;
    if (categoryId == null) {
      adminTopologyMutations.reportError('Сначала создайте раздел.');
      return;
    }
    final revision = widget.state.topology?.revision;
    if (revision == null) return;
    await adminTopologyMutations.actions.createChannel(
      categoryId,
      revision,
      adminChannelName.text,
      adminChannelKind,
    );
    if (!mounted || adminTopologyMutations.error != null) return;
    adminChannelName.clear();
  }
}
