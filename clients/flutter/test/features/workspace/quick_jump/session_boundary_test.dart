import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/workspace/quick_jump/state/entry.dart';
import 'package:boohtacord_desktop/src/features/direct/conversations/candidate_page.dart';

import 'support.dart';

void main() {
  test('late DM creation cannot open a dialog after session closes', () async {
    final h = JumpHarness();
    addTearDown(h.owner.dispose);
    final created = Completer<String>();
    h.api.createResult = created.future;
    final opening = h.owner.open(
      const QuickJumpEntry(targetId: 'new', label: 'New'),
    );
    h.scope.close();
    created.complete('dm-new');
    expect(await opening, isFalse);
    expect(h.openedDirect, isNull);
    expect(h.directs, isEmpty);
  });
  test(
    'a repeated cursor ends paging instead of an automatic request loop',
    () async {
      final h = JumpHarness();
      addTearDown(h.owner.dispose);
      final first = h.owner.load();
      h.api.pending.single.complete(
        const DirectCandidatePage(items: [], nextAfter: 'same'),
      );
      await first;
      final second = h.owner.load();
      h.api.pending.last.complete(
        const DirectCandidatePage(items: [], nextAfter: 'same'),
      );
      await second;
      expect(h.owner.nextAfter, isNull);
      expect(h.owner.canLoad, isFalse);
      expect(h.api.requests, [null, 'same']);
    },
  );
}
