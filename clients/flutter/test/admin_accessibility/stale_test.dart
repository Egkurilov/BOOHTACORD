import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/admin/readiness/model.dart';

import 'fixture.dart';

class StaleAdminApi extends AccessibleAdminApi {
  @override
  Future<AdminReadiness> inspectAdminReadiness() async {
    final date = DateTime.now().toUtc().subtract(const Duration(seconds: 30));
    final probe = AdminReadinessProbe.fromJson({
      'status': 'ready',
      'sampled_at': date.toIso8601String(),
    });
    return AdminReadiness(
      status: 'ready',
      checkedAt: date,
      database: probe,
      sfu: probe,
      storage: probe,
    );
  }
}

void main() {
  testWidgets(
    'actual readiness announces stale data without presenting old success as fresh',
    (tester) async {
      await mountAdmin(tester, api: StaleAdminApi());
      final tab = find.byKey(const ValueKey('admin-section-tab-readiness'));
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      final stale = find.text('Нет свежего подтверждения готовности');
      expect(stale, findsOneWidget);
      expect(find.text('Сервисы готовы'), findsNothing);
      expect(
        find.ancestor(
          of: stale,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
    },
  );
}
