import 'package:boohtacord_desktop/src/features/admin/audit/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/audit/filter.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_audit_test_support.dart';

void main() {
  testWidgets('no-match state keeps pagination and retry available', (
    tester,
  ) async {
    var calls = 0;
    final controller = AdminAuditController(({String? before}) async {
      calls++;
      if (before == null) {
        return AdminAuditPage(
          events: [auditEvent(id: 'new', type: 'CHANNEL_CREATED')],
          nextCursor: 'older',
        );
      }
      if (calls == 2) throw StateError('private payload');
      return AdminAuditPage(
        events: [auditEvent(id: 'old', type: 'VOICE_LEASE_ISSUED')],
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
    await tester.tap(find.text('Показать более ранние'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить журнал аудита.'), findsOneWidget);
    expect(find.textContaining('private payload'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('admin-audit-retry-more')));
    await tester.pumpAndSettle();
    expect(find.text('Создано голосовое подключение'), findsOneWidget);
    expect(calls, 3);
  });
}
