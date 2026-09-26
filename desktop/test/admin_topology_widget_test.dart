import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

Future<AppState> _openChannels(WidgetTester tester, TopologyTestApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1400);
  final state = AppState(api)..topology = api.current;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AdminScreen(state: state)),
    ),
  );
  await tester.pump();
  await tester.tap(find.widgetWithText(ChoiceChip, 'Каналы'));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Категорию выше'),
        )
        .onPressed,
    isNull,
  );
  final picker = find.byType(DropdownButtonFormField<String>).first;
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Дополнительная').last);
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('locks topology controls until reorder and refresh finish', (
    tester,
  ) async {
    final api = TopologyTestApi()..pending = Completer<void>();
    final state = await _openChannels(tester, api);
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
    final state = await _openChannels(tester, api);
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
