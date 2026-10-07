import 'dart:ui' show SemanticsRole, Tristate;

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

void main() {
  testWidgets('media empty state is accessible and polls only while selected', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final semantics = tester.ensureSemantics();
    final api = TopologyTestApi();
    final state = AppState(api)..topology = api.current;
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
    final media = find.byKey(const ValueKey('admin-section-tab-media'));
    await tester.ensureVisible(media);
    await tester.pumpAndSettle();
    await tester.tap(media);
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('admin-section-tabs-semantics')),
          )
          .getSemanticsData().role,
      SemanticsRole.tabBar,
    );
    final mediaSemantics = tester.getSemantics(media);
    expect(mediaSemantics.getSemanticsData().role, SemanticsRole.tab);
    expect(
      mediaSemantics.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(api.screenMetricsLoads, 1);
    expect(
      find.text('Свежих показателей пока нет. Откройте демонстрацию у зрителя.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('без имён и идентификаторов участников'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(api.screenMetricsLoads, 2);
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-channels')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(api.screenMetricsLoads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
