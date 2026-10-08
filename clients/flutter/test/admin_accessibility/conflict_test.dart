import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/http/api_failure.dart';

import 'fixture.dart';

void main() {
  testWidgets(
    'pending role save announces saving without a second submission',
    (tester) async {
      final api = AccessibleAdminApi()..pendingRoleSave = Completer<void>();
      await mountAdmin(tester, api: api);
      final roles = find.byKey(const ValueKey('admin-section-tab-roles'));
      await tester.ensureVisible(roles);
      await tester.tap(roles);
      await tester.pumpAndSettle();
      final permission = find.widgetWithText(
        CheckboxListTile,
        'Создавать текстовые каналы',
      );
      await revealAdminControl(tester, permission);
      await tester.tap(permission);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Сохранить');
      await revealAdminControl(tester, save);
      await tester.tap(save);
      await tester.pump();
      final label = find.text('Сохраняем…');
      expect(
        find.ancestor(
          of: label,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Сохраняем…'),
            )
            .onPressed,
        isNull,
      );
      api.pendingRoleSave!.complete();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'actual role save conflict exposes a live comparison without discarding the draft',
    (tester) async {
      final api = AccessibleAdminApi()
        ..roleSaveFailure = const ApiFailure('Conflict', status: 409);
      await mountAdmin(tester, api: api);
      final roles = find.byKey(const ValueKey('admin-section-tab-roles'));
      await tester.ensureVisible(roles);
      await tester.tap(roles);
      await tester.pumpAndSettle();
      final permission = find.widgetWithText(
        CheckboxListTile,
        'Создавать текстовые каналы',
      );
      await tester.ensureVisible(permission);
      await tester.tap(permission);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Сохранить');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      final review = find.byKey(const ValueKey('admin-role-conflict-review'));
      await tester.scrollUntilVisible(
        review,
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.ancestor(
          of: review,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        permission,
        -350,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<CheckboxListTile>(permission).value, true);
    },
  );
}
