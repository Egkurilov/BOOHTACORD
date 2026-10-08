import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminArchiveTextChannelBinding
    on AdminScreenStateContext {
  @override
  Future<void> adminArchiveTextChannel(List<GuildChannel> channels) =>
      executeAdminArchiveTextChannel(channels);
}

extension AdminScreenStateAdminArchiveTextChannelBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminArchiveTextChannel(
    List<GuildChannel> channels,
  ) async {
    final channel = channels
        .where(
          (item) =>
              item.id == adminArchiveChannelId && item.kind == ChannelKind.text,
        )
        .firstOrNull;
    final revision = widget.state.topology?.revision;
    if (channel == null || revision == null) return;
    await adminTopologyMutations.actions.archiveTextChannel(channel, revision);
  }
}
