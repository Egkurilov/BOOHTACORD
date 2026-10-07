import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/core/http/api_failure.dart';
import 'package:boohtacord_desktop/src/features/admin/role_permissions/model.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

class _RolePermissionsTestApi extends TopologyTestApi {
  int loads = 0;

  @override
  Future<RolePolicyPage> loadRolePolicies() async {
    loads++;
    final permissions = {
      for (final permission in GuildPermission.values)
        permission: loads > 1 && permission == GuildPermission.textCreate,
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

  @override
  Future<void> saveMemberRolePolicy({
    required int revision,
    required Map<GuildPermission, bool> values,
    required bool confirmDeleteGrants,
  }) async {
    throw const ApiFailure('conflict', status: 409);
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
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-roles')));
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

  testWidgets('role conflict exposes before/current/proposed review', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
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
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-roles')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Создавать текстовые каналы'),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(api.loads, greaterThan(1));
    expect(
      find.byKey(const ValueKey('admin-role-conflict-review')),
      findsOneWidget,
    );
    expect(find.textContaining('Текстовые · создавать'), findsOneWidget);
    expect(find.text('Принять серверные данные'), findsOneWidget);
    expect(find.text('Применить мой draft'), findsOneWidget);
  });
}
