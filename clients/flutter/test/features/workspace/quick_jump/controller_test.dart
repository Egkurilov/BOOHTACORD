import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/direct/conversations/candidate_page.dart';

import 'support.dart';

void main() {
  test(
    'loads explicitly paged people and deduplicates known DM peers and self',
    () async {
      final h = JumpHarness();
      addTearDown(h.owner.dispose);
      h.directs = [
        const DirectConversation(
          id: 'dm-existing',
          participantId: 'peer',
          displayName: 'Peer',
          unreadCount: 0,
        ),
      ];
      final load = h.owner.load();
      h.api.pending.single.complete(
        const DirectCandidatePage(
          items: [
            DirectCandidate(id: 'self', displayName: 'Self'),
            DirectCandidate(id: 'peer', displayName: 'Peer duplicate'),
            DirectCandidate(id: 'new', displayName: 'New member'),
          ],
          nextAfter: 'cursor-2',
        ),
      );
      await load;
      expect(h.owner.entries.map((e) => e.targetId), ['peer', 'new']);
      expect(h.owner.nextAfter, 'cursor-2');
      final more = h.owner.load();
      expect(h.api.requests, [null, 'cursor-2']);
      h.api.pending.last.complete(
        const DirectCandidatePage(items: [], nextAfter: null),
      );
      await more;
      expect(h.owner.nextAfter, isNull);
    },
  );
  test(
    'disposed or replaced session never accepts late candidate pages',
    () async {
      final h = JumpHarness();
      final load = h.owner.load();
      h.scope.close();
      h.api.pending.single.complete(
        const DirectCandidatePage(
          items: [DirectCandidate(id: 'other', displayName: 'Other')],
          nextAfter: null,
        ),
      );
      await load;
      expect(h.owner.entries, isEmpty);
      h.owner.dispose();
    },
  );
  test('new person selection creates DM then opens only authoritative refreshed result', () async {
    final h = JumpHarness();
    addTearDown(h.owner.dispose);
    final load = h.owner.load();
    h.api.pending.single.complete(
      const DirectCandidatePage(
        items: [DirectCandidate(id: 'new', displayName: 'New member')],
        nextAfter: null,
      ),
    );
    await load;
    h.api.directs = [
      const DirectConversation(
        id: 'dm-new',
        participantId: 'new',
        displayName: 'New member',
        unreadCount: 0,
      ),
    ];
    expect(await h.owner.open(h.owner.entries.single), isTrue);
    expect(h.api.creates, 1);
    expect(h.openedDirect?.id, 'dm-new');
  });
  test('denied DM create never navigates', () async {
    final h = JumpHarness();
    addTearDown(h.owner.dispose);
    h.api.deny = true;
    final load = h.owner.load();
    h.api.pending.single.complete(
      const DirectCandidatePage(
        items: [DirectCandidate(id: 'new', displayName: 'New member')],
        nextAfter: null,
      ),
    );
    await load;
    expect(await h.owner.open(h.owner.entries.single), isFalse);
    expect(h.openedDirect, isNull);
    expect(h.owner.error, isNotNull);
  });
}
