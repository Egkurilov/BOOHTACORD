import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/models.dart';

import 'fixture.dart';

void main() {
  testWidgets(
    'member list preserves its scroll offset through desktop and compact resize',
    (tester) async {
      final api = AccessibleAdminApi()
        ..accounts = [
          for (var index = 0; index < 30; index++)
            AdminAccount(
              accountId: 'fixture-$index',
              login: 'fixture-$index',
              displayName: 'Участник $index',
              role: 'MEMBER',
              blocked: false,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
        ];
      await mountAdmin(tester, api: api);
      final scroll = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
      final offset = tester.state<ScrollableState>(scroll).position.pixels;
      expect(offset, greaterThan(100));
      for (final size in [
        const Size(600, 844),
        const Size(1440, 900),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(scroll).position.pixels,
          closeTo(offset, .01),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
