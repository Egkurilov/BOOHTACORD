import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_screen_test_support.dart';

void main() {
  testWidgets('edits and saves a channel description in the inspector', (
    tester,
  ) async {
    final api = DescriptionTopologyApi();
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-channels')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('admin-topology-channel:text-1')),
    );
    await tester.pumpAndSettle();

    final descriptionField = find.byKey(
      const ValueKey('admin-topology-channel-description'),
    );
    expect(descriptionField, findsOneWidget);
    expect(
      tester.widget<TextField>(descriptionField).controller!.text,
      'Старое описание',
    );
    await tester.enterText(descriptionField, 'Новое описание');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Сохранить описание'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.savedDescription, 'Новое описание');
    expect(
      state.topology!.categories.single.channels.single.description,
      'Новое описание',
    );
  });
}
