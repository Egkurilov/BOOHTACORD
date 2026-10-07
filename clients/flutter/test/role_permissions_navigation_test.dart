import 'package:boohtacord_desktop/src/features/admin/role_permissions/panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'role_permissions_fake_api.dart';

void main() {
  testWidgets('leaving asks before discarding a dirty draft', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          key: const ValueKey('open-roles'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: RolePermissionsPanel(
              api: RolePermissionsTestApi(), onSaved: () async {},
            )),
          )),
          child: const Text('Open roles'),
        ),
      )),
    ));
    await tester.tap(find.byKey(const ValueKey('open-roles')));
    await tester.pumpAndSettle();
    final textCreate = find.byKey(
      const ValueKey('permission-checkbox:channel.text.create'),
    );
    await tester.tap(textCreate);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Остаться в редакторе'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(textCreate).value, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить черновик и продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Open roles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Tab reaches role tabs, permission controls, and action bar',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: RolePermissionsPanel(
          api: RolePermissionsTestApi(), onSaved: () async {},
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('permission-checkbox:channel.text.create')),
      );
      await tester.pumpAndSettle();
      final member = find.byKey(const ValueKey('role-permissions-tab-member'));
      final administrator = find.byKey(
        const ValueKey('role-permissions-tab-administrator'),
      );
      final permission = find.byKey(
        const ValueKey('permission-checkbox:channel.text.create'),
      );
      final save = find.text('Сохранить');
      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();

      var sawMember = false;
      var sawAdministrator = false;
      var sawPermission = false;
      var sawAction = false;
      for (var index = 0; index < 20; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        sawMember = sawMember || _hasPrimaryFocus(tester, member);
        sawAdministrator = sawAdministrator ||
            _hasPrimaryFocus(tester, administrator);
        sawPermission = sawPermission ||
            _hasPrimaryFocus(tester, permission);
        sawAction = sawAction || _hasPrimaryFocus(tester, save);
      }
      expect(sawMember, isTrue);
      expect(sawAdministrator, isTrue);
      expect(sawPermission, isTrue);
      expect(sawAction, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

bool _hasPrimaryFocus(WidgetTester tester, Finder target) =>
    tester
        .widgetList<Focus>(
          find.ancestor(of: target, matching: find.byType(Focus)),
        )
        .any((focus) => focus.focusNode?.hasPrimaryFocus == true);
