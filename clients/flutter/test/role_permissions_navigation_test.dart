import 'package:boohtacord_desktop/src/features/admin/role_permissions/panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'role_permissions_fake_api.dart';

void main() {
  testWidgets('leaving asks before discarding a dirty draft', (tester) async {
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
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Остаться в редакторе'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(textCreate).value, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить черновик и продолжить'));
    await tester.pumpAndSettle();
    expect(find.text('Open roles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
