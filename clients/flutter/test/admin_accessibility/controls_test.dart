import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  testWidgets(
    'scaled member search text has its full line height and IME-safe save target',
    (tester) async {
      await mountAdmin(
        tester,
        scale: 2,
        insets: const EdgeInsets.only(bottom: 300),
      );
      final search = find.byKey(const ValueKey('admin-member-search'));
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pump();
      final editable = tester
          .state<EditableTextState>(
            find.descendant(of: search, matching: find.byType(EditableText)),
          )
          .renderEditable;
      expect(
        editable.size.height,
        greaterThanOrEqualTo(editable.preferredLineHeight),
      );
      final save = find.byKey(const ValueKey('save-account:account-a'));
      await tester.ensureVisible(save);
      await tester.pump();
      expect(tester.getSize(save).height, greaterThanOrEqualTo(44));
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(844 - 300));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('compact buttons expose44px touch targets without hover', (
    tester,
  ) async {
    await mountAdmin(tester);
    for (final key in ['save-account:account-a', 'reset-account:account-a']) {
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.pump();
      expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
    }
  });
  testWidgets(
    'member popup Escape restores initiator and system Back closes transient first',
    (tester) async {
      await mountAdmin(tester, size: const Size(1440, 900));
      final target = find.byKey(
        const ValueKey('admin-member-actions:account-a'),
      );
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('Назначить администратором'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Назначить администратором'), findsNothing);
      expect(
        tester
            .widget<Focus>(
              find.byKey(const ValueKey('admin-member-action-focus:account-a')),
            )
            .focusNode!
            .hasFocus,
        true,
      );
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Назначить администратором'), findsNothing);
      expect(
        find.byKey(const ValueKey('admin-workspace-header')),
        findsOneWidget,
      );
    },
  );
}
