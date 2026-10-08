import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminReorderChannelBinding on AdminScreenStateContext {
  @override
  Future<void> adminReorderChannel(int direction) =>
      executeAdminReorderChannel(direction);
}

extension AdminScreenStateAdminReorderChannelBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminReorderChannel(int direction) async {
    final topology = widget.state.topology;
    final category = topology?.categories
        .where((item) => item.id == adminCategoryId)
        .firstOrNull;
    if (topology == null || category == null || adminChannelId == null) return;
    final channel = category.channels
        .where((item) => item.id == adminChannelId)
        .firstOrNull;
    if (channel == null) return;
    await adminTopologyMutations.actions.reorderChannel(
      category.id,
      channel,
      topology.revision,
      direction,
    );
  }
}
