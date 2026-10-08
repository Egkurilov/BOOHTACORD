import '../../../../models.dart';

class QuickJumpEntry {
  const QuickJumpEntry({
    required this.targetId,
    required this.label,
    this.channel,
    this.direct,
  });
  final String targetId, label;
  final GuildChannel? channel;
  final DirectConversation? direct;
  bool get isPerson => channel == null;
}
