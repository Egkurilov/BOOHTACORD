import '../../../../models.dart';

class QuickJumpEffects {
  const QuickJumpEffects({
    required this.acceptTopology,
    required this.acceptDirects,
    required this.openChannel,
    required this.openDirect,
  });
  final void Function(ChannelTopology) acceptTopology;
  final void Function(List<DirectConversation>) acceptDirects;
  final Future<void> Function(GuildChannel) openChannel;
  final Future<void> Function(DirectConversation) openDirect;
}
