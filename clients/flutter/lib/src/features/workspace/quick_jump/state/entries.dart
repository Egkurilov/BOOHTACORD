import '../../../../models.dart';
import 'entry.dart';

List<QuickJumpEntry> jumpEntries({
  required ChannelTopology? topology,
  required List<DirectConversation> directs,
  required List<DirectCandidate> people,
  required String? self,
  required String query,
}) {
  final entries = <QuickJumpEntry>[];
  for (final category in topology?.categories ?? <ChannelCategory>[]) {
    for (final channel in category.channels) {
      entries.add(
        QuickJumpEntry(
          targetId: channel.id,
          label: channel.name,
          channel: channel,
        ),
      );
    }
  }
  final seen = <String>{?self};
  for (final direct in directs) {
    if (seen.add(direct.participantId)) {
      entries.add(
        QuickJumpEntry(
          targetId: direct.participantId,
          label: direct.displayName,
          direct: direct,
        ),
      );
    }
  }
  for (final person in people) {
    if (seen.add(person.id)) {
      entries.add(
        QuickJumpEntry(targetId: person.id, label: person.displayName),
      );
    }
  }
  final needle = query.trim().toLowerCase();
  return entries
      .where((e) => needle.isEmpty || e.label.toLowerCase().contains(needle))
      .toList(growable: false);
}
