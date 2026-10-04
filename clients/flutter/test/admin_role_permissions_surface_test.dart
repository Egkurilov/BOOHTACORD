import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/admin/role_permissions/model.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

class _RolePermissionsTestApi extends TopologyTestApi {
  @override
  Future<RolePolicyPage> loadRolePolicies() async {
    final permissions = {
      for (final permission in GuildPermission.values) permission: false,
    };
    return RolePolicyPage(1, [
      RolePolicy(
        role: GuildRole.administrator,
        displayName: 'Администратор',
        editable: false,
        permissions: permissions,
      ),
      RolePolicy(
        role: GuildRole.member,
        displayName: 'Пользователь',
        editable: true,
        permissions: permissions,
      ),
    ]);
  }
}

void main() {
  testWidgets('admin permission checkboxes have a visible Material surface', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = _RolePermissionsTestApi();
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Роли'));
    await tester.pumpAndSettle();

    final permissionTile = find.widgetWithText(
      CheckboxListTile,
      'Создавать текстовые каналы',
    );
    expect(
      find.byType(CheckboxListTile),
      findsNWidgets(GuildPermission.values.length),
    );
    expect(tester.takeException(), isNull);
    expect(tester.widget<CheckboxListTile>(permissionTile).value, isFalse);

    await tester.tap(permissionTile);
    await tester.pumpAndSettle();

    expect(tester.widget<CheckboxListTile>(permissionTile).value, isTrue);
    expect(tester.takeException(), isNull);
  });
}
