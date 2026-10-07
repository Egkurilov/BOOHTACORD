import 'package:boohtacord_desktop/src/features/admin/role_permissions/panel.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'role_permissions_fake_api.dart';

void main() {
  testWidgets('dirty member draft survives confirmed role switch', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    final api = RolePermissionsTestApi();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: RolePermissionsPanel(api: api, onSaved: () async {}),
    )));
    await tester.pumpAndSettle();
    final textCreate = find.byKey(const ValueKey('permission-checkbox:channel.text.create'));
    await tester.tap(textCreate);
    await tester.pumpAndSettle();
    expect(find.text('Есть несохранённые изменения'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('role-permissions-tab-administrator')));
    await tester.pumpAndSettle();
    expect(find.text('Перейти, сохранив черновик'), findsOneWidget);
    await tester.tap(find.text('Перейти, сохранив черновик'));
    await tester.pumpAndSettle();
    expect(find.text('Разрешения администратора обязательны и не изменяются.'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(textCreate).onChanged, isNull);

    await tester.tap(find.byKey(const ValueKey('role-permissions-tab-member')));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(textCreate).value, isTrue);
    expect(find.text('Есть несохранённые изменения'), findsOneWidget);
  });

  testWidgets('defaults and cancel reflect the actual dirty state', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: RolePermissionsPanel(
        api: RolePermissionsTestApi(), onSaved: () async {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Изменения не внесены'), findsOneWidget);
    await tester.tap(find.text('По умолчанию'));
    await tester.pumpAndSettle();
    expect(find.text('Есть несохранённые изменения'), findsOneWidget);
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Изменения не внесены'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('permission-checkbox:channel.text.create'))).value, isFalse);
  });

  testWidgets('another-role revision change requires explicit conflict review', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = RolePermissionsTestApi();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: RolePermissionsPanel(api: api, onSaved: () async {}),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
      const ValueKey('permission-checkbox:channel.text.create'),
    ));
    await tester.pumpAndSettle();
    api.revision++;

    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('role-permission-conflict-review')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(
      const ValueKey('conflict:category.create:current'),
    )).data, 'Запрещено');
    expect(find.text('Сохранить'), findsNothing);
    expect(find.text('Проверено — применить мой вариант'), findsOneWidget);
    expect(api.saves, 0);
    await tester.tap(find.text('Проверено — применить мой вариант'));
    await tester.pumpAndSettle();
    expect(api.savedRevision, 2);
    expect(api.savedValues![GuildPermission.textCreate], isTrue);
    expect(api.savedValues![GuildPermission.categoryCreate], isFalse);
    expect(api.saves, 1);
  });
}
