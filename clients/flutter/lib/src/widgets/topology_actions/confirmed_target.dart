import '../../models.dart';

bool confirmedTopologyTargetIsCurrent(
  ChannelTopology? topology,
  Object target,
  int confirmedRevision,
) {
  if (topology == null || topology.revision != confirmedRevision) return false;

  if (target is ChannelCategory) {
    final category = topology.categories
        .where((item) => item.id == target.id)
        .firstOrNull;
    return category != null &&
        category.name == target.name &&
        category.channels.isEmpty;
  }

  if (target is GuildChannel) {
    final channel = topology.categories
        .expand((category) => category.channels)
        .where((item) => item.id == target.id)
        .firstOrNull;
    return channel != null &&
        channel.name == target.name &&
        channel.kind == target.kind &&
        channel.admissionClosed == target.admissionClosed;
  }

  return false;
}
