import 'package:boohtacord_desktop/src/features/admin/audit/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_audit_test_support.dart';

void main() {
  testWidgets('compact filters open an accessible sheet without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    final controller = AdminAuditController(
      ({String? before}) async => AdminAuditPage(events: [
        auditEvent(id: '1', type: 'CHANNEL_CREATED'),
      ]),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(auditApp(controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin-audit-filter-open')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('admin-audit-filter-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin-audit-filter-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-audit-scope-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-audit-from-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-audit-to-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-audit-type-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-audit-actor-filter')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
