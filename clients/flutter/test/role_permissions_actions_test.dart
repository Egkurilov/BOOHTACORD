import 'package:boohtacord_desktop/src/features/admin/role_permissions/panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'role_permissions_fake_api.dart';

void main() {
  testWidgets('delete grant needs confirmation and action bar fits short screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 360);
    addTearDown(tester.view.reset);
    final api = RolePermissionsTestApi();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: RolePermissionsPanel(api: api, onSaved: () async {}),
    )));
    await tester.pumpAndSettle();
    final categoryDelete = find.byKey(
      const ValueKey('permission-checkbox:category.delete'),
    );
    final deleteCheckbox = find.descendant(
      of: categoryDelete,
      matching: find.byType(Checkbox),
    );
    await tester.dragUntilVisible(
      deleteCheckbox,
      find.byType(SingleChildScrollView).first,
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(categoryDelete).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('role-permissions-action-bar'))).top,
      ),
    );
    await tester.tap(deleteCheckbox);
    await tester.pumpAndSettle();
    expect(find.text('Разрешение удаления действует на любые каналы.'), findsOneWidget);
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Выдать участникам право удаления?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(api.saves, 0);
    expect(find.text('Есть несохранённые изменения'), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('role-permissions-action-bar'))).bottom,
        lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  });
}
