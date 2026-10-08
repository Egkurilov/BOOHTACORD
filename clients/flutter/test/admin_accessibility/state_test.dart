import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  testWidgets(
    'resize preserves member draft, selection and filter without submitting',
    (tester) async {
      await mountAdmin(tester, size: const Size(1440, 900));
      final role = find.byType(DropdownButtonFormField<String>).last;
      await tester.tap(role);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Администратор').last);
      await tester.pumpAndSettle();
      for (final size in [
        const Size(600, 844),
        const Size(390, 844),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final current = tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>).last,
        );
        expect(current.initialValue, 'ADMINISTRATOR');
        expect(
          tester
              .widget<Semantics>(
                find.byKey(const ValueKey('admin-section-tab-members')),
              )
              .properties
              .selected,
          true,
        );
        expect(tester.takeException(), isNull);
      }
      final search = find.byKey(const ValueKey('admin-member-search'));
      await tester.enterText(search, 'long-login');
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, 'long-login');
    },
  );
  testWidgets('pending member save announces its busy state', (tester) async {
    final api = AccessibleAdminApi()..pendingSave = Completer<void>();
    await mountAdmin(tester, api: api);
    final save = find.byKey(const ValueKey('save-account:account-a'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == 'Сохраняем изменения участника',
      ),
      findsOneWidget,
    );
    api.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
