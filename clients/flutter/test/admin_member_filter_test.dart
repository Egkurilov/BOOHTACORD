import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/admin/audit/filter.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/admin_member_filter.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

AdminAccount account(
  String id,
  String name,
  String login,
  String role, {
  bool blocked = false,
}) => AdminAccount(
  accountId: id,
  login: login,
  displayName: name,
  role: role,
  blocked: blocked,
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
    final blockedAccount = account(
      'c',
      'Вера',
      'vera',
      'MEMBER',
      blocked: true,
    );
    expect(
      filterAdminMembers(
        [accounts.last, blockedAccount],
        search: '',
        role: 'ALL',
        status: 'BLOCKED',
      ),
      [blockedAccount],
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
      greaterThan(120),
      reason: 'compact member filters share the available width',
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

  testWidgets(
    'member filters count results, filter status and reset at 320 px',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
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

      expect(find.text('Показано: 2 из 2 загруженных'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('admin-member-search')),
        'без совпадений',
      );
      await tester.pump();
      expect(find.text('Показано: 0 из 2 загруженных'), findsOneWidget);
      expect(find.text('По текущим фильтрам участников нет.'), findsOneWidget);
      expect(find.text('Сбросить фильтры'), findsOneWidget);
      await tester.tap(find.text('Сбросить фильтры'));
      await tester.pumpAndSettle();
      expect(find.text('Показано: 2 из 2 загруженных'), findsOneWidget);
      expect(find.text('Алиса'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('admin-member-status-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Заблокирован').last);
      await tester.pumpAndSettle();
      expect(find.text('Показано: 0 из 2 загруженных'), findsOneWidget);
      expect(find.text('По текущим фильтрам участников нет.'), findsOneWidget);
      await tester.tap(find.text('Сбросить фильтры'));
      await tester.pumpAndSettle();
      expect(find.text('Показано: 2 из 2 загруженных'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('admin-member-status-filter')),
            )
            .initialValue,
        'ALL',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('member and audit filters survive section changes', (
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
    await tester.enterText(
      find.byKey(const ValueKey('admin-member-search')),
      'ALICE',
    );
    await tester.pumpAndSettle();

    final auditTab = find.byKey(const ValueKey('admin-section-tab-audit'));
    await tester.ensureVisible(auditTab);
    await tester.tap(auditTab);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-audit-scope-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Голос').last);
    await tester.pumpAndSettle();

    final membersTab = find.byKey(const ValueKey('admin-section-tab-members'));
    await tester.ensureVisible(membersTab);
    await tester.tap(membersTab);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('admin-member-search')))
          .controller!
          .text,
      'ALICE',
    );

    await tester.ensureVisible(auditTab);
    await tester.tap(auditTab);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<AdminAuditScope>>(
            find.byKey(const ValueKey('admin-audit-scope-filter')),
          )
          .initialValue,
      AdminAuditScope.voice,
    );
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

  testWidgets(
    'compact members keep pathological identities usable at 2x text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final api = TopologyTestApi()
        ..accounts = [
          account(
            'long',
            'Очень длинное отображаемое имя администратора с редкими символами — 0123456789',
            'login_with_an_extremely_long_identifier_that_must_not_escape_the_card',
            'ADMINISTRATOR',
          ),
        ];
      final state = AppState(api)..topology = api.current;
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            home: Scaffold(body: AdminScreen(state: state)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final memberName = find.text(
        'Очень длинное отображаемое имя администратора с редкими символами — 0123456789',
      );
      await tester.scrollUntilVisible(
        memberName,
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(memberName, findsOneWidget);
      expect(
        find.textContaining('@login_with_an_extremely_long_identifier'),
        findsOneWidget,
      );
      expect(find.text('Роль'), findsOneWidget);
      final roleLabelRect = tester.getRect(find.text('Роль'));
      final roleField = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('role:long:'),
      );
      final roleFieldRect = tester.getRect(roleField);
      expect(
        roleLabelRect.bottom,
        lessThanOrEqualTo(roleFieldRect.top),
        reason: 'the 2× role label stays outside the outlined control',
      );
      expect(
        tester.getSemantics(roleField).getSemanticsData().label,
        contains('Роль'),
        reason: 'the dropdown keeps its accessible role label',
      );
      expect(find.textContaining('Роль: login_with_'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
