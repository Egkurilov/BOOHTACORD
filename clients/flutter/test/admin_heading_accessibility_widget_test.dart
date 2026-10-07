import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

void main() {
  testWidgets('admin panel focuses and announces its semantic heading', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = TopologyTestApi();
    final state = AppState(api)..topology = api.current;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    final headingFocus = tester
        .widget<Focus>(find.byKey(const ValueKey('admin-screen-title-focus')))
        .focusNode!;
    expect(headingFocus.hasFocus, isTrue);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('admin-screen-title')))
          .flagsCollection
          .isHeader,
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
    semantics.dispose();
  });
}
