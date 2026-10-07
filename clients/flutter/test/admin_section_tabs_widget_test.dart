import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

Future<AppState> _openMedia(WidgetTester tester, TopologyTestApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  final state = AppState(api)..topology = api.current;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AdminScreen(state: state)),
    ),
  );
  await tester.pumpAndSettle();
  final media = find.byKey(const ValueKey('admin-section-tab-media'));
  await tester.ensureVisible(media);
  await tester.tap(media);
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('admin tabs use one horizontally scrollable web-style row', (
    tester,
  ) async {
    final state = await _openMedia(tester, TopologyTestApi());
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });
    final keys = [
      'guild',
      'members',
      'roles',
      'channels',
      'audit',
      'media',
      'readiness',
    ]
        .map((name) => ValueKey('admin-section-tab-$name'));
    expect(
      keys.map((key) => tester.getTopLeft(find.byKey(key)).dy).toSet(),
      hasLength(1),
    );
    final scroll = find.byKey(const ValueKey('admin-section-tabs-scroll'));
    expect(
      tester.widget<SingleChildScrollView>(scroll).scrollDirection,
      Axis.horizontal,
    );
    await tester.drag(scroll, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-section-tab-media')).hitTestable(),
      findsNothing,
    );
    await tester.drag(scroll, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-section-tab-media')).hitTestable(),
      findsOneWidget,
    );
    final readiness = find.byKey(const ValueKey('admin-section-tab-readiness'));
    await tester.ensureVisible(readiness);
    await tester.pumpAndSettle();
    expect(readiness.hitTestable(), findsOneWidget);
  });

  testWidgets('desktop tab divider fills the centered admin panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
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
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-section-tabs-scroll'))).width,
      880,
    );
    expect(
      find.byKey(const ValueKey('admin-section-tab-readiness')),
      findsOneWidget,
    );
  });
}
