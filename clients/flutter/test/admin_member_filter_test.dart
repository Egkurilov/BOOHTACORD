import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/core/http/api_failure.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/admin_member_filter.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
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

class _ConflictMemberApi extends ApiClient {
  int loads = 0;

  @override
  Future<AdminAccountPage> listAdminAccounts({
    String? cursor,
    int limit = 100,
  }) async {
    loads++;
    return AdminAccountPage(
      accounts: [
        AdminAccount(
          accountId: 'conflict-account',
          login: 'alice',
          displayName: 'Алиса',
          role: 'MEMBER',
          blocked: loads > 1,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, loads),
        ),
      ],
    );
  }

  @override
  Future<void> updateAdminAccount({
    required String accountId,
    required String role,
    required bool blocked,
    DateTime? expectedUpdatedAt,
  }) async {
    throw const ApiFailure(
      'Участник изменён другим администратором.',
      status: 409,
    );
  }
}

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
            find
                .ancestor(
                  of: find.text('Участ.'),
                  matching: find.byType(FittedBox),
                )
                .first,
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
            find
                .ancestor(
                  of: find.text('Админ.'),
                  matching: find.byType(FittedBox),
                )
                .first,
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
    expect(
      find.byKey(const ValueKey('admin-member-row:a')),
      findsOneWidget,
      reason: 'expanded members use a compact table-like row',
    );
    expect(
      find.byKey(const ValueKey('admin-member-actions:a')),
      findsOneWidget,
      reason: 'expanded members expose contextual actions without a full form',
    );
    expect(find.text('Роль: alice'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member conflict keeps draft and exposes comparison actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final api = _ConflictMemberApi();
    final state = AppState(api);
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('role:conflict-account:MEMBER')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Администратор').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('save-account:conflict-account')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Другой администратор изменил @alice'), findsOneWidget);
    expect(
      find.textContaining('Ваше изменение: Администратор'),
      findsOneWidget,
    );
    expect(find.text('Принять серверные данные'), findsOneWidget);
    expect(find.text('Применить мой draft'), findsOneWidget);
  });
}
