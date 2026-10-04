import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/admin_member_filter.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

AdminAccount account(String id, String name, String login, String role) =>
    AdminAccount(
      accountId: id,
      login: login,
      displayName: name,
      role: role,
      blocked: false,
      createdAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  final accounts = [
    account('a', 'Алиса', 'alice', 'ADMINISTRATOR'),
    account('b', 'Борис', 'bob', 'MEMBER'),
  ];

  test('filters loaded accounts by name, login and role', () {
    expect(
      filterAdminMembers(accounts, search: '  АЛИС ', role: 'ALL'),
      [accounts.first],
    );
    expect(
      filterAdminMembers(accounts, search: 'BOB', role: 'MEMBER'),
      [accounts.last],
    );
    expect(
      filterAdminMembers(accounts, search: 'bob', role: 'ADMINISTRATOR'),
      isEmpty,
    );
  });

  testWidgets('member directory keeps count and filters visible cards', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final api = TopologyTestApi()..accounts = accounts;
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: AdminScreen(state: state)));
    await tester.pumpAndSettle();

    expect(find.text('Участники 2'), findsOneWidget);
    expect(find.text('Алиса'), findsOneWidget);
    expect(find.text('Борис'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('admin-member-search')),
      'ALICE',
    );
    await tester.pump();
    expect(find.text('Алиса'), findsOneWidget);
    expect(find.text('Борис'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('admin-member-search')),
      '',
    );
    await tester.tap(find.byKey(const ValueKey('admin-member-role-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Администратор').last);
    await tester.pumpAndSettle();
    expect(find.text('Алиса'), findsOneWidget);
    expect(find.text('Борис'), findsNothing);
    expect(find.text('Участники 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
