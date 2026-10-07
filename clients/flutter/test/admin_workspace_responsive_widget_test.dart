import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

void main() {
  testWidgets('admin header adapts between medium and wide layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = TopologyTestApi();
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AdminScreen(state: state))),
    );
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(900, 900);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('admin-screen-title')))
          .getSemanticsData()
          .label,
      'Администрирование',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-header'))),
      const Size(900, 56),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-nav-toggle'))),
      const Size(44, 44),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-close'))),
      const Size(44, 44),
    );

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-workspace-nav-toggle')),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-close'))),
      const Size(36, 36),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-header'))),
      const Size(1200, 64),
    );
  });
}
