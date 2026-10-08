import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminSaveChannelDescriptionBinding
    on AdminScreenStateContext {
  @override
  Future<void> adminSaveChannelDescription(GuildChannel channel) =>
      executeAdminSaveChannelDescription(channel);
}

extension AdminScreenStateAdminSaveChannelDescriptionBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminSaveChannelDescription(GuildChannel channel) async {
    final revision = widget.state.topology?.revision;
    if (revision != null) {
      await adminTopologyMutations.actions.saveDescription(
        channel,
        revision,
        adminChannelDescription.text,
      );
    }
  }
}
