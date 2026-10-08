import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminRenameChannelBinding on AdminScreenStateContext {
  @override
  Future<void> adminRenameChannel(GuildChannel channel) =>
      executeAdminRenameChannel(channel);
}

extension AdminScreenStateAdminRenameChannelBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminRenameChannel(GuildChannel channel) async {
    final revision = widget.state.topology?.revision;
    if (revision != null) {
      await adminTopologyMutations.actions.renameChannel(
        channel,
        revision,
        adminChannelRename.text,
      );
    }
  }
}
