import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

Future<AppState> _openChannels(WidgetTester tester, TopologyTestApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1400);
  final state = AppState(api)..topology = api.current;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AdminScreen(state: state)),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('admin-section-tab-channels')));
  await tester.pumpAndSettle();
  expect(
    tester
        .widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Категорию выше'),
        )
        .onPressed,
    isNull,
  );
  final picker = find.byType(DropdownButtonFormField<String>).first;
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Дополнительная').last);
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('compact member directory matches web typography and targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    var navigationToggled = false;
    var closed = false;
    final api = TopologyTestApi()
      ..accounts = [
        AdminAccount(
          accountId: 'member-1',
          login: 'member',
          displayName: 'Member Name',
          role: 'MEMBER',
          blocked: false,
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ];
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminScreen(
            state: state,
            onToggleNavigation: () => navigationToggled = true,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageTitle = tester.getSemantics(
      find.byKey(const ValueKey('admin-screen-title')),
    );
    expect(pageTitle.getSemanticsData().label, 'Администрирование');
    expect(pageTitle.getSemanticsData().flagsCollection.isHeader, isTrue);
    expect(find.text('Администрирование'), findsOneWidget);
    expect(find.text('УПРАВЛЕНИЕ ГИЛЬДИЕЙ'), findsNothing);
    expect(
      find.text('Управление гильдией и доступом участников.'),
      findsNothing,
    );

    final memberSectionTitle = tester.widget<Text>(
      find.byKey(const ValueKey('admin-members-section-title')),
    );
    expect(memberSectionTitle.style?.fontSize, 20);
    expect(memberSectionTitle.style?.height, 28 / 20);
    expect(memberSectionTitle.style?.fontWeight, FontWeight.w600);

    final accountName = tester.widget<Text>(find.text('Member Name'));
    expect(accountName.style?.fontSize, 16);
    expect(accountName.style?.height, 20 / 16);
    expect(accountName.style?.fontWeight, FontWeight.w600);

    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-nav-toggle'))),
      const Size(44, 44),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-close'))),
      const Size(44, 44),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('admin-workspace-nav-toggle')));
    await tester.pump();
    expect(navigationToggled, isTrue);
    await tester.tap(find.byKey(const ValueKey('admin-workspace-close')));
    await tester.pump();
    expect(closed, isTrue);

    tester.view.physicalSize = const Size(900, 900);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('admin-screen-title')))
          .getSemanticsData()
          .label,
      'Администрирование',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-header'))),
      const Size(900, 56),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-nav-toggle'))),
      const Size(44, 44),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-close'))),
      const Size(44, 44),
    );

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('admin-screen-title')))
          .getSemanticsData()
          .label,
      'Администрирование',
    );
    expect(
      find.byKey(const ValueKey('admin-workspace-nav-toggle')),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-close'))),
      const Size(36, 36),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('admin-workspace-header'))),
      const Size(1200, 64),
    );
  });

  testWidgets('announces member and audit loading states to screen readers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = TopologyTestApi()
      ..pendingAccounts = Completer<AdminAccountPage>();
    final state = AppState(api)..topology = api.current;
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pump();

    final membersLoading = find.byKey(const ValueKey('admin-members-loading'));
    expect(find.text('Загружаем список участников…'), findsOneWidget);
    expect(
      tester
          .getSemantics(membersLoading)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    api.pendingAccounts!.complete(const AdminAccountPage(accounts: []));
    await tester.pumpAndSettle();
    expect(find.text('Участников пока нет.'), findsOneWidget);

    api.pendingAudit = Completer<AdminAuditPage>();
    await tester.tap(find.byKey(const ValueKey('admin-section-tab-audit')));
    await tester.pump();
    final auditLoading = find.byKey(const ValueKey('admin-audit-loading'));
    expect(find.text('Загружаем аудит…'), findsOneWidget);
    expect(
      tester
          .getSemantics(auditLoading)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    api.pendingAudit!.complete(const AdminAuditPage(events: []));
    await tester.pumpAndSettle();
    expect(find.text('Записей пока нет.'), findsOneWidget);
  });

  testWidgets('admin panel focuses and announces its semantic heading', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final api = TopologyTestApi();
    final state = AppState(api)..topology = api.current;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    final headingFocus = tester
        .widget<Focus>(find.byKey(const ValueKey('admin-screen-title-focus')))
        .focusNode!;
    expect(headingFocus.hasFocus, isTrue);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('admin-screen-title')))
          .flagsCollection
          .isHeader,
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('locks topology controls until reorder and refresh finish', (
    tester,
  ) async {
    final api = TopologyTestApi()..pending = Completer<void>();
    final state = await _openChannels(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    await tester.tap(find.widgetWithText(OutlinedButton, 'Категорию выше'));
    await tester.pump();
    expect(api.revisions, [1]);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Категорию выше'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );

    api.pending!.complete();
    await tester.pumpAndSettle();
    expect(state.topology!.revision, 2);
    expect(state.topology!.categories.first.id, 'second');
    expect(api.revisions, [1]);
    expect(
      find.text('Порядок категорий сохранён. Топология обновлена.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.refresh))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('recovers 409 and retries with the refreshed revision', (
    tester,
  ) async {
    final api = TopologyTestApi()..conflictOnce = true;
    final state = await _openChannels(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    await tester.tap(find.widgetWithText(OutlinedButton, 'Категорию выше'));
    await tester.pumpAndSettle();
    expect(api.revisions, [1]);
    expect(state.topology!.revision, 2);
    expect(
      find.text(
        'Топология изменилась. Список обновлён — проверьте выбор и повторите действие.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Категорию выше'));
    await tester.pumpAndSettle();
    expect(api.revisions, [1, 2]);
    expect(state.topology!.revision, 3);
    expect(state.topology!.categories.first.id, 'second');
    expect(
      find.text('Порядок категорий сохранён. Топология обновлена.'),
      findsOneWidget,
    );
  });
}
