import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminCloseVoiceAdmissionBinding
    on AdminScreenStateContext {
  @override
  Future<void> adminCloseVoiceAdmission(List<GuildChannel> channels) =>
      executeAdminCloseVoiceAdmission(channels);
}

extension AdminScreenStateAdminCloseVoiceAdmissionBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminCloseVoiceAdmission(
    List<GuildChannel> channels,
  ) async {
    final channel = channels
        .where(
          (item) =>
              item.id == adminCloseVoiceChannelId &&
              item.kind == ChannelKind.voice,
        )
        .firstOrNull;
    final revision = widget.state.topology?.revision;
    if (channel == null || revision == null || channel.admissionClosed) return;
    await adminTopologyMutations.actions.closeVoiceAdmission(channel, revision);
  }
}
