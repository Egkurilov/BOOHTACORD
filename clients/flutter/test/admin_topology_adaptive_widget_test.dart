import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_panel_fixture.dart';

void main() {
  testWidgets('long names clip and compact selection drills into inspector', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final width in [360.0, 800.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(topologyTestApp(topologyCategories));
      await tester.pumpAndSettle();
      expect(find.text(topologyLongName), findsWidgets);
      expect(tester.takeException(), isNull);
      if (width == 360) {
        await tester.tap(
          find.byKey(const ValueKey('admin-topology-channel:voice')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('admin-topology-back')),
          findsOneWidget,
        );
        expect(find.text('ГОЛОСОВОЙ КАНАЛ'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('admin-topology-back')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('admin-topology-tree')),
          findsOneWidget,
        );
      }
      if (width == 800) {
        await tester.tap(
          find.byKey(const ValueKey('admin-topology-channel:voice')),
        );
        await tester.pumpAndSettle();
        expect(find.text('ГОЛОСОВОЙ КАНАЛ'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });
}
