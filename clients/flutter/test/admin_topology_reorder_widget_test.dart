import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';
import 'admin_topology_screen_test_support.dart';

void main() {
  testWidgets('locks topology controls until reorder and refresh finish', (
    tester,
  ) async {
    final api = TopologyTestApi()..pending = Completer<void>();
    final state = await openChannels(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    await tester.tap(find.widgetWithText(OutlinedButton, 'Категорию выше'));
    await tester.pump();
    expect(api.revisions, [1]);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Категорию выше'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );

    api.pending!.complete();
    await tester.pumpAndSettle();
    expect(state.topology!.revision, 2);
    expect(state.topology!.categories.first.id, 'second');
    expect(api.revisions, [1]);
    expect(
      find.text('Порядок категорий сохранён. Топология обновлена.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('recovers 409 and retries with the refreshed revision', (
    tester,
  ) async {
    final api = TopologyTestApi()..conflictOnce = true;
    final state = await openChannels(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    await tester.tap(find.widgetWithText(OutlinedButton, 'Категорию выше'));
    await tester.pumpAndSettle();
    expect(api.revisions, [1]);
    expect(state.topology!.revision, 2);
    expect(
      find.text(
        'Топология изменилась. Список обновлён — проверьте выбор и повторите действие.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Категорию выше'));
    await tester.pumpAndSettle();
    expect(api.revisions, [1, 2]);
    expect(state.topology!.revision, 3);
    expect(state.topology!.categories.first.id, 'second');
    expect(
      find.text('Порядок категорий сохранён. Топология обновлена.'),
      findsOneWidget,
    );
  });
}
