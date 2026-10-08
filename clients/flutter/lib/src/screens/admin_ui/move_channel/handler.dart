import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminMoveChannelBinding on AdminScreenStateContext {
  @override
  Future<void> adminMoveChannel() => executeAdminMoveChannel();
}

extension AdminScreenStateAdminMoveChannelBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminMoveChannel() async {
    final topology = widget.state.topology;
    if (topology == null ||
        adminMoveChannelId == null ||
        adminMoveTargetCategoryId == null) {
      return;
    }
    final channel = topology.categories
        .expand((category) => category.channels)
        .where((item) => item.id == adminMoveChannelId)
        .firstOrNull;
    if (channel == null) return;
    await adminTopologyMutations.actions.moveChannel(
      channel,
      topology.revision,
      adminMoveTargetCategoryId!,
    );
  }
}
