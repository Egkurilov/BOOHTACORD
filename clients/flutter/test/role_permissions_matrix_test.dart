import 'package:boohtacord_desktop/src/features/admin/role_permissions/panel.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'role_permissions_fake_api.dart';

void main() {
  for (final width in const [360.0, 390.0, 600.0, 768.0, 840.0, 1024.0, 1440.0, 1920.0]) {
    testWidgets('permission matrix fits ${width.toInt()} px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);
      final api = RolePermissionsTestApi();
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: RolePermissionsPanel(api: api, onSaved: () async {}),
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('role-permissions-action-bar')), findsOneWidget);
      for (final permission in GuildPermission.values) {
        expect(find.byKey(ValueKey('permission-checkbox:${permission.wireName}')), findsOneWidget);
      }
      expect(find.text('Архивация сохраняет историю.'), findsOneWidget);
      expect(find.text('Закрытие доступа отключает участников.'), findsOneWidget);
      expect(find.text('Удалять можно только пустые разделы.'), findsOneWidget);
      expect(find.byKey(const ValueKey('permission-group:Текстовые каналы')), findsOneWidget);
      expect(find.byKey(const ValueKey('role-permissions-focus-order')), findsOneWidget);
      expect(
        find.text('Создавать'),
        width >= 600 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('administrator remains read-only for all six permissions', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: RolePermissionsPanel(
        api: RolePermissionsTestApi(), onSaved: () async {},
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-permissions-tab-administrator')));
    await tester.pumpAndSettle();

    for (final permission in GuildPermission.values) {
      expect(
        tester.widget<CheckboxListTile>(find.byKey(ValueKey('permission-checkbox:${permission.wireName}'))).onChanged,
        isNull,
      );
    }
    expect(find.text('Разрешения администратора обязательны и не изменяются.'), findsOneWidget);
    expect(find.text('Просмотр роли'), findsOneWidget);
    expect(find.text('По умолчанию'), findsNothing);
    expect(find.text('Сохранить'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact matrix groups each object with its two permissions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: RolePermissionsPanel(
          api: RolePermissionsTestApi(), onSaved: () async {},
        ),
      )));
      await tester.pumpAndSettle();
      const groups = <String, List<String>>{
        'Текстовые каналы': ['channel.text.create', 'channel.text.delete'],
        'Голосовые каналы': ['channel.voice.create', 'channel.voice.delete'],
        'Разделы': ['category.create', 'category.delete'],
      };
      for (final entry in groups.entries) {
        final card = find.byKey(ValueKey('permission-group:${entry.key}'));
        expect(tester.getRect(card).height, greaterThan(150));
        for (final permission in entry.value) {
          expect(find.descendant(
            of: card,
            matching: find.byKey(ValueKey('permission-checkbox:$permission')),
          ), findsOneWidget);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}
