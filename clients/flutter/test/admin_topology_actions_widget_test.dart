import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_action_test_support.dart';
import 'admin_topology_screen_test_support.dart';

void main() {
  testWidgets('archive mutates only after explicit confirmation', (tester) async {
    final api = TopologyActionApi();
    final state = await openChannels(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });
    await _selectChannel(tester, 'text-1');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Архивировать канал'));
    await tester.pumpAndSettle();
    expect(find.text('Подтверждение архивации'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();
    expect(api.archivedId, isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Архивировать канал'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Архивировать канал'));
    await tester.pumpAndSettle();
    expect(api.archivedId, 'text-1');
    expect(api.mutationRevision, 1);
  });

  testWidgets('voice admission closes only after explicit confirmation', (
    tester,
  ) async {
    final api = TopologyActionApi();
    final state = await openChannels(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });
    await _selectChannel(tester, 'voice-1');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Закрыть вход'));
    await tester.pumpAndSettle();
    expect(find.text('Подтверждение закрытия'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();
    expect(api.closedId, isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Закрыть вход'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Закрыть вход'));
    await tester.pumpAndSettle();
    expect(api.closedId, 'voice-1');
    expect(api.mutationRevision, 1);
  });

  testWidgets('move sends the selected channel and target category', (
    tester,
  ) async {
    final api = TopologyActionApi();
    final state = await openChannels(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });
    await _selectChannel(tester, 'text-1');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Переместить канал'));
    await tester.pumpAndSettle();
    expect(api.movedId, 'text-1');
    expect(api.targetId, 'first');
    expect(api.mutationRevision, 1);
  });
}

Future<void> _selectChannel(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('admin-topology-channel:$id')));
  await tester.pumpAndSettle();
}
