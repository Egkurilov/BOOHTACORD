import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  testWidgets(
    'tabs activate with Enter and Space and expose visible keyboard focus',
    (tester) async {
      await mountAdmin(tester, size: const Size(1440, 900));
      final guild = find.byKey(const ValueKey('admin-section-tab-guild'));
      final ink = find.descendant(of: guild, matching: find.byType(InkWell));
      final focus = tester.widget<InkWell>(ink).focusNode!;
      focus.requestFocus();
      await tester.pumpAndSettle();
      final outline = tester.widget<DecoratedBox>(
        find.descendant(
          of: guild,
          matching: find.byKey(const ValueKey('admin-tab-focus-outline')),
        ),
      );
      expect((outline.decoration as BoxDecoration).border, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(guild).properties.selected, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('admin-section-tab-members')),
            )
            .properties
            .selected,
        true,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(focus.hasFocus, true);
    },
  );
}
