import 'dart:async';

import 'package:boohtacord_desktop/src/features/admin/audit/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/audit/filter.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_audit_test_support.dart';

void main() {
  testWidgets('shows initial loading and empty states', (tester) async {
    final page = Completer<AdminAuditPage>();
    final controller = AdminAuditController(({String? before}) => page.future);
    addTearDown(controller.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(auditApp(controller));
    await tester.pump();
    expect(find.text('Загружаем аудит…'), findsOneWidget);
    page.complete(const AdminAuditPage(events: []));
    await tester.pumpAndSettle();
    expect(find.text('Записей пока нет.'), findsOneWidget);
  });

  testWidgets('shows error and empty filtered states', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final controller = AdminAuditController(({String? before}) async {
      throw StateError('private response');
    });
    addTearDown(controller.dispose);
    await tester.pumpWidget(auditApp(controller));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить журнал аудита.'), findsOneWidget);
    expect(find.text('private response'), findsNothing);
    await controller.load();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows safe unknown event summary and allowed details only', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final event = auditEvent(
      id: 'event-1',
      type: 'FUTURE_EVENT_TYPE',
      targetId: 'target-1',
      targetName: 'Member',
      targetLogin: 'member',
    );
    final controller = AdminAuditController(
      ({String? before}) async => AdminAuditPage(events: [event]),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(auditApp(controller));
    await tester.pumpAndSettle();
    expect(find.text('Другое событие управления'), findsOneWidget);
    expect(find.text('Moderator (@mod)'), findsOneWidget);
    expect(find.text('Другое событие управления'), findsOneWidget);
    expect(find.text('Member (@member)'), findsOneWidget);
    expect(find.textContaining('target-1'), findsNothing);
    final details = find.byKey(const ValueKey('admin-audit-details:event-1'));
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('Тип · FUTURE_EVENT_TYPE'), findsOneWidget);
    expect(find.text('Объект · Member (@member)'), findsOneWidget);
    expect(find.text('Время · 06.10.2026 10:15'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
    expect(find.byKey(const ValueKey('admin-audit-day:2026-10-06')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows no matches without reloading the API', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    var calls = 0;
    final controller = AdminAuditController(({String? before}) async {
      calls++;
      return AdminAuditPage(
        events: [auditEvent(id: 'event-1', type: 'CHANNEL_CREATED')],
      );
    });
    addTearDown(controller.dispose);
    await tester.pumpWidget(auditApp(controller));
    await tester.pumpAndSettle();
    controller.updateFilters(
      const AdminAuditFilters(scope: AdminAuditScope.voice),
    );
    await tester.pumpAndSettle();
    expect(find.text('Среди загруженных записей совпадений нет.'), findsOneWidget);
    expect(calls, 1);
  });
}
