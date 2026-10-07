import 'package:boohtacord_desktop/src/features/admin/members/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/members/models.dart';
import 'package:boohtacord_desktop/src/features/admin/members/panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';

void main() {
  testWidgets('cards adapt to compact width and keep drafts after resize', (tester) async {
    final api = MembersApiFake()..pages[null] = AdminAccountPage(accounts: [member('a'), member('b', role: 'ADMINISTRATOR')]);
    final controller = AdminMembersController(api);
    addTearDown(controller.dispose);
    await controller.load();
    resize(tester, 390);
    await tester.pumpWidget(host(controller));
    expect(find.byKey(const ValueKey('admin-member-card:a')), findsOneWidget);
    controller.updateDraftBlocked('a', true);
    controller.search.text = 'user-a';
    controller.setRoleFilter('MEMBER');
    resize(tester, 839);
    await tester.pumpWidget(host(controller));
    expect(find.byKey(const ValueKey('admin-member-card:a')), findsOneWidget);
    resize(tester, 1440);
    await tester.pumpWidget(host(controller));
    expect(find.byKey(const ValueKey('admin-member-row:a')), findsOneWidget);
    expect(controller.drafts['a']?.blocked, isTrue);
    expect(controller.search.text, 'user-a');
    expect(controller.roleFilter, 'MEMBER');
  });

  testWidgets('filtered no-results differs from a truly empty directory', (tester) async {
    final api = MembersApiFake()..pages[null] = AdminAccountPage(accounts: [member('a')]);
    final controller = AdminMembersController(api);
    addTearDown(controller.dispose);
    await controller.load();
    controller.search.text = 'missing';
    resize(tester, 390);
    await tester.pumpWidget(host(controller));
    expect(find.text('По текущему фильтру участники не найдены.'), findsOneWidget);
    controller.replacePages(const []);
    await tester.pump();
    expect(find.text('Участников пока нет.'), findsOneWidget);
  });

  testWidgets('conflict review shows baseline server value and proposed draft', (tester) async {
    final api = MembersApiFake()..pages[null] = AdminAccountPage(accounts: [member('a')]);
    final controller = AdminMembersController(api);
    addTearDown(controller.dispose);
    await controller.load();
    controller.updateDraftRole('a', 'ADMINISTRATOR');
    controller.conflicts['a'] = AdminMemberConflict(before: member('a'), current: member('a', blocked: true, version: 2));
    resize(tester, 390);
    await tester.pumpWidget(host(controller));
    expect(find.text('Было'), findsOneWidget);
    expect(find.text('Сейчас на сервере'), findsOneWidget);
    expect(find.text('Ваш черновик'), findsOneWidget);
  });

  testWidgets('closing reset URL restores focus to that member actions', (tester) async {
    final api = MembersApiFake()..pages[null] = AdminAccountPage(accounts: [member('a')]);
    final controller = AdminMembersController(api);
    addTearDown(controller.dispose);
    await controller.load();
    controller.resetResult = AdminMemberResetResult(member('a'), AdminPasswordResetLink(url: 'https://example.test/reset', expiresAt: DateTime.utc(2026)));
    resize(tester, 390);
    await tester.pumpWidget(host(controller));
    await tester.tap(find.byTooltip('Закрыть и удалить ссылку'));
    await tester.pumpAndSettle();
    final actions = tester.widget<PopupMenuButton<String>>(find.byKey(const ValueKey('admin-member-actions:a')));
    expect(actions.focusNode!.hasFocus, isTrue);
  });

  testWidgets('long identity, admin role, and blocked badge fit compact card', (tester) async {
    final long = AdminAccount(
      accountId: 'long', login: 'l' * 120, displayName: 'Long User ' * 30,
      role: 'ADMINISTRATOR', blocked: true, createdAt: DateTime.utc(2026),
    );
    final api = MembersApiFake()..pages[null] = AdminAccountPage(accounts: [long]);
    final controller = AdminMembersController(api);
    addTearDown(controller.dispose);
    await controller.load();
    resize(tester, 390);
    await tester.pumpWidget(host(controller));
    expect(find.byKey(const ValueKey('admin-member-card:long')), findsOneWidget);
    expect(find.text('Закрыт'), findsOneWidget);
    await tester.tap(find.text(long.displayName));
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('admin-member-role:long')),
    ).initialValue, 'ADMINISTRATOR');
    expect(tester.takeException(), isNull);
  });
}

void resize(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
}

Widget host(AdminMembersController controller) => MaterialApp(
  home: Scaffold(body: AdminMembersPanel(
      controller: controller,
      currentAccountId: 'self',
      voiceParticipantIds: const {},
    )),
);
