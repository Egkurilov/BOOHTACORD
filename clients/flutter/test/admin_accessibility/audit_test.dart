import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/models.dart';

import 'fixture.dart';

Future<void> openAudit(WidgetTester tester) async {
  final tab = find.byKey(const ValueKey('admin-section-tab-audit'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pump();
}

void main() {
  testWidgets('audit loading and failures are live announcements', (
    tester,
  ) async {
    final api = AccessibleAdminApi()
      ..pendingAudit = Completer<AdminAuditPage>();
    await mountAdmin(tester, api: api);
    await openAudit(tester);
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('admin-audit-loading')))
          .properties
          .liveRegion,
      true,
    );
    api.pendingAudit!.completeError(StateError('Аудит временно недоступен'));
    await tester.pumpAndSettle();
    final error = find.textContaining('Аудит временно недоступен');
    expect(error, findsOneWidget);
    expect(
      find.ancestor(
        of: error,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'audit filters scroll above the IME rather than overflowing the shell',
    (tester) async {
      await mountAdmin(tester, insets: const EdgeInsets.only(bottom: 300));
      expect(
        tester.takeException(),
        isNull,
        reason: 'member shell before changing section',
      );
      await openAudit(tester);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final actor = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Инициатор',
      );
      await tester.ensureVisible(actor);
      await tester.tap(actor);
      await tester.pump();
      expect(tester.getRect(actor).bottom, lessThanOrEqualTo(544));
    },
  );
  testWidgets(
    'loaded audit handles long names and large text without dropping event details',
    (tester) async {
      final api = AccessibleAdminApi()
        ..pendingAudit = Completer<AdminAuditPage>();
      await mountAdmin(tester, scale: 2, api: api, reducedMotion: true);
      await openAudit(tester);
      api.pendingAudit!.complete(
        AdminAuditPage(
          events: [
            AdminAuditEvent(
              id: 'fixture-event',
              eventType: 'ACCOUNT_ADMIN_STATE_UPDATED',
              createdAt: DateTime(2026, 10, 9),
              actorDisplayName: 'Длинное имя ' * 20,
              actorLogin: 'long-login' * 20,
              targetUserId: 'fixture-target',
              targetDisplayName: 'Объект ' * 30,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final event = find.byType(ExpansionTile);
      await tester.scrollUntilVisible(
        event,
        350,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final title = find.text('Изменены роль или доступ участника');
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.text('Тип · ACCOUNT_ADMIN_STATE_UPDATED'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<ExpansionTile>(event).expansionAnimationStyle,
        AnimationStyle.noAnimation,
      );
    },
  );
}
