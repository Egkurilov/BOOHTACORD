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
    expect(filterAdminMembers(accounts, search: '  АЛИС ', role: 'ALL'), [
      accounts.first,
    ]);
    expect(filterAdminMembers(accounts, search: 'BOB', role: 'MEMBER'), [
      accounts.last,
    ]);
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Участники 2'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('admin-member-role-filter')))
          .width,
      81,
      reason: 'the web compact layout reserves 81 px for the role filter',
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('admin-member-role-filter')))
          .height,
      44,
      reason: 'the web compact role filter is 44 px tall',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-member-search'))).height,
      44,
      reason: 'the web compact search field is 44 px tall',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-member-role-filter')),
        matching: find.byIcon(Icons.arrow_drop_down),
      ),
      findsNothing,
      reason: 'the web compact select hides its native dropdown arrow',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-member-role-filter')),
        matching: find.text('Все'),
      ),
      findsOneWidget,
      reason: 'the compact filter uses a readable short selected label',
    );
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
    await tester.tap(find.text('Пользователь').last);
    await tester.pumpAndSettle();
    expect(find.text('Алиса'), findsNothing);
    expect(find.text('Борис'), findsOneWidget);
    final selectedMemberRole = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('admin-member-role-filter')),
        matching: find.text('Участ.'),
      ),
    );
    expect(selectedMemberRole.softWrap, isFalse);
    expect(selectedMemberRole.maxLines, 1);
    expect(
      tester
          .widget<FittedBox>(
            find.ancestor(
              of: find.text('Участ.'),
              matching: find.byType(FittedBox),
            ).first,
          )
          .fit,
      BoxFit.scaleDown,
      reason: 'the full compact member label scales down instead of truncating',
    );

    await tester.tap(find.byKey(const ValueKey('admin-member-role-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Администратор').last);
    await tester.pumpAndSettle();
    expect(find.text('Алиса'), findsOneWidget);
    expect(find.text('Борис'), findsNothing);
    expect(find.text('Участники 2'), findsOneWidget);
    final selectedAdminRole = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('admin-member-role-filter')),
        matching: find.text('Админ.'),
      ),
    );
    expect(selectedAdminRole.softWrap, isFalse);
    expect(selectedAdminRole.maxLines, 1);
    expect(
      tester
          .widget<FittedBox>(
            find.ancestor(
              of: find.text('Админ.'),
              matching: find.byType(FittedBox),
            ).first,
          )
          .fit,
      BoxFit.scaleDown,
      reason: 'the full compact administrator label scales down instead of truncating',
    );
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('admin-member-role-filter')))
          .width,
      121,
      reason: 'the web desktop layout reserves 121 px for the role filter',
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('admin-member-role-filter')))
          .height,
      44,
      reason: 'the web desktop role filter is 44 px tall',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin-member-role-filter')),
        matching: find.byIcon(Icons.arrow_drop_down),
      ),
      findsOneWidget,
      reason: 'the web desktop select keeps its native dropdown arrow',
    );
    expect(tester.takeException(), isNull);
  });
}
