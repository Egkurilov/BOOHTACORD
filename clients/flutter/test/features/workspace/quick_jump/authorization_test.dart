import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/direct/conversations/candidate_page.dart';
import 'package:boohtacord_desktop/src/features/workspace/quick_jump/state/entry.dart';

import 'support.dart';

void main() {
  test(
    'failed open cannot strand an independent pending people load',
    () async {
      final h = JumpHarness();
      addTearDown(h.owner.dispose);
      final load = h.owner.load();
      h.api.deny = true;
      expect(
        await h.owner.open(const QuickJumpEntry(targetId: 'new', label: 'New')),
        isFalse,
      );
      h.api.pending.single.complete(
        const DirectCandidatePage(items: [], nextAfter: null),
      );
      await load;
      expect(h.owner.loading, isFalse);
      expect(h.owner.loaded, isTrue);
    },
  );
  test('paging error retains entries and permits explicit retry', () async {
    final h = JumpHarness();
    addTearDown(h.owner.dispose);
    final first = h.owner.load();
    h.api.pending.single.complete(
      const DirectCandidatePage(
        items: [DirectCandidate(id: 'p', displayName: 'Peer')],
        nextAfter: 'next',
      ),
    );
    await first;
    final second = h.owner.load();
    h.api.pending.last.completeError(StateError('offline'));
    await second;
    expect(h.owner.entries.single.targetId, 'p');
    expect(h.owner.canLoad, isTrue);
    final retry = h.owner.load();
    expect(h.api.requests, [null, 'next', 'next']);
    h.api.pending.last.complete(
      const DirectCandidatePage(items: [], nextAfter: null),
    );
    await retry;
    expect(h.owner.error, isNull);
  });
  test('revoked existing DM is not opened or recreated', () async {
    final h = JumpHarness();
    addTearDown(h.owner.dispose);
    const direct = DirectConversation(
      id: 'dm-old',
      participantId: 'peer',
      displayName: 'Peer',
      unreadCount: 0,
    );
    h.directs = [direct];
    expect(await h.owner.open(h.owner.entries.single), isFalse);
    expect(h.api.creates, 0);
    expect(h.openedDirect, isNull);
  });
  test(
    'voice channel selection refreshes ACL and invokes only channel navigation',
    () async {
      final h = JumpHarness();
      addTearDown(h.owner.dispose);
      const channel = GuildChannel(
        id: 'voice',
        name: 'Voice',
        kind: ChannelKind.voice,
        admissionClosed: false,
      );
      h.topology = const ChannelTopology(
        revision: 1,
        categories: [
          ChannelCategory(
            id: 'category',
            name: 'Category',
            channels: [channel],
          ),
        ],
      );
      final entry = h.owner.entries.single;
      expect(await h.owner.open(entry), isFalse);
      expect(h.openedChannel, isNull);
      h.api.serverTopology = h.topology!;
      expect(await h.owner.open(entry), isTrue);
      expect(h.api.topologyReads, 2);
      expect(h.openedChannel, channel);
      expect(h.api.creates, 0);
    },
  );
}
