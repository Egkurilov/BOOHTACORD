import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'role_permissions_fake_api.dart';

void main() {
  testWidgets('switching admin sections confirms and preserves the role draft', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = RolePermissionsTestApi();
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminScreen(state: state))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-roles')));
    await tester.pumpAndSettle();
    final textCreate = find.byKey(
      const ValueKey('permission-checkbox:channel.text.create'),
    );
    await tester.tap(textCreate);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-members')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Остаться в редакторе'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(textCreate).value, isTrue);

    await tester.tap(find.byKey(const ValueKey('admin-section-tab-members')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить черновик и продолжить'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('permission-checkbox:channel.text.create')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
