import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

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
