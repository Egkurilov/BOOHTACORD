import 'package:boohtacord_desktop/src/features/admin/role_permissions/panel.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'role_permissions_fake_api.dart';

void main() {
  testWidgets('409 review shows actual before/current/proposed and keeps draft', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = RolePermissionsTestApi()..conflictOnNextSave = true;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: RolePermissionsPanel(api: api, onSaved: () async {}),
    )));
    await tester.pumpAndSettle();
    final textCreate = find.byKey(const ValueKey('permission-checkbox:channel.text.create'));
    await tester.tap(textCreate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('role-permission-conflict-review')), findsOneWidget);
    expect(find.text('До изменения'), findsWidgets);
    expect(find.text('Текущее на сервере'), findsWidgets);
    expect(find.text('Ваш вариант'), findsWidgets);
    expect(find.text('Разрешено'), findsWidgets);
    expect(find.text('Запрещено'), findsWidgets);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('conflict:category.create:before'))).data,
      'Запрещено',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('conflict:category.create:current'))).data,
      'Разрешено',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('conflict:category.create:proposed'))).data,
      'Запрещено',
    );
    expect(tester.widget<CheckboxListTile>(textCreate).value, isTrue);
    expect(find.text('Сравнение готово для проверки'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reviewed draft saves against the refreshed server revision', (tester) async {
    final api = RolePermissionsTestApi()..conflictOnNextSave = true;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: RolePermissionsPanel(api: api, onSaved: () async {}),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('permission-checkbox:channel.text.create')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверено — применить мой вариант'));
    await tester.pumpAndSettle();

    expect(api.savedRevision, 2);
    expect(api.savedValues![GuildPermission.textCreate], isTrue);
    expect(api.savedValues![GuildPermission.categoryCreate], isFalse);
    expect(api.saves, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refresh with a dirty draft requires review before rebasing',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.reset);
      final api = RolePermissionsTestApi();
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: RolePermissionsPanel(api: api, onSaved: () async {}),
      )));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('permission-checkbox:channel.text.create')),
      );
      await tester.pumpAndSettle();
      api.member = Map.of(api.member)..[GuildPermission.categoryCreate] = true;
      api.revision++;

      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('role-permission-conflict-review')), findsOneWidget);
      expect(api.saves, 0);
      expect(
        tester.widget<Text>(find.byKey(
          const ValueKey('conflict:category.create:current'),
        )).data,
        'Разрешено',
      );
      expect(find.text('Проверено — применить мой вариант'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Проверено — применить мой вариант'));
      await tester.pumpAndSettle();
      expect(api.savedRevision, 2);
      expect(api.savedValues![GuildPermission.textCreate], isTrue);
      expect(api.savedValues![GuildPermission.categoryCreate], isFalse);
      expect(api.saves, 1);
    },
  );
}
