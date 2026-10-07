import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:boohtacord_desktop/src/features/admin/shell/section_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boohtacord_desktop/src/features/admin/readiness/panel.dart';

import 'admin_topology_fake_api.dart';

void main() {
  for (final viewport in const [
    Size(360, 844),
    Size(390, 844),
    Size(430, 932),
    Size(844, 390),
    Size(600, 900),
    Size(768, 900),
    Size(840, 900),
    Size(900, 900),
    Size(1024, 768),
    Size(1024, 900),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'admin content panel centers within web max-width at ${viewport.width} px',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        addTearDown(tester.view.reset);
        final api = TopologyTestApi();
        final state = AppState(api)..topology = api.current;
        addTearDown(state.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AdminScreen(state: state)),
          ),
        );
        await tester.pumpAndSettle();

        final panel = tester.getRect(
          find.byKey(const ValueKey('admin-content-panel')),
        );
        final expectedWidth = viewport.width < 880 ? viewport.width : 880.0;
        expect(panel.width, expectedWidth);
        expect(panel.left, (viewport.width - expectedWidth) / 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('admin shell remains usable at text scale 2.0', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final api = TopologyTestApi();
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(body: AdminScreen(state: state)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final section in AdminSection.values) {
      final tab = find.byKey(ValueKey('admin-section-tab-${section.name}'));
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: section.name);
    }
  });

  testWidgets('resizing keeps the selected admin section', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.reset);
    final api = TopologyTestApi();
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-readiness')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AdminReadinessPanel), findsOneWidget);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AdminReadinessPanel), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-section-tab-readiness')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
