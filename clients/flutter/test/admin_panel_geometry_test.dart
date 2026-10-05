import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

void main() {
  for (final viewport in const [
    Size(390, 844),
    Size(900, 900),
    Size(1440, 900),
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
}
