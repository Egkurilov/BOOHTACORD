import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/widgets/topology_actions/confirmed_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = GuildChannel(
    id: 'channel-1',
    name: 'Чат',
    kind: ChannelKind.text,
    admissionClosed: false,
  );
  const category = ChannelCategory(
    id: 'category-1',
    name: 'Общее',
    channels: [channel],
  );
  const topology = ChannelTopology(revision: 7, categories: [category]);

  test('accepts only the same confirmed channel and topology revision', () {
    expect(confirmedTopologyTargetIsCurrent(topology, channel, 7), isTrue);
    expect(confirmedTopologyTargetIsCurrent(topology, channel, 8), isFalse);
  });

  test('rejects a channel that disappeared or changed after confirmation', () {
    const emptyTopology = ChannelTopology(
      revision: 7,
      categories: [
        ChannelCategory(id: 'category-1', name: 'Общее', channels: []),
      ],
    );
    const renamed = GuildChannel(
      id: 'channel-1',
      name: 'Новый чат',
      kind: ChannelKind.text,
      admissionClosed: false,
    );
    const renamedTopology = ChannelTopology(
      revision: 7,
      categories: [
        ChannelCategory(id: 'category-1', name: 'Общее', channels: [renamed]),
      ],
    );
    expect(
      confirmedTopologyTargetIsCurrent(emptyTopology, channel, 7),
      isFalse,
    );
    expect(
      confirmedTopologyTargetIsCurrent(renamedTopology, channel, 7),
      isFalse,
    );
  });

  test('rejects deleting a category that is no longer empty', () {
    const empty = ChannelCategory(id: 'empty', name: 'Пустой', channels: []);
    const occupied = ChannelTopology(
      revision: 7,
      categories: [
        ChannelCategory(id: 'empty', name: 'Пустой', channels: [channel]),
      ],
    );
    expect(confirmedTopologyTargetIsCurrent(occupied, empty, 7), isFalse);
  });
}
