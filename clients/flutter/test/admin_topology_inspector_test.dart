import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_panel_fixture.dart';

void main() {
  testWidgets('tree selection opens voice inspector and shows closed state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(topologyTestApp(topologyCategories));
    await tester.tap(
      find.byKey(const ValueKey('admin-topology-channel:voice')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ГОЛОСОВОЙ КАНАЛ'), findsOneWidget);
    expect(find.text('Вход закрыт'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty topology offers category creation without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(topologyTestApp([]));
    expect(find.text('Категорий пока нет.'), findsOneWidget);
    expect(find.byTooltip('Создать категорию'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
