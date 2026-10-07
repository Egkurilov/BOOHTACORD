import 'dart:async';

import 'package:boohtacord_desktop/src/features/admin/audit/controller.dart';
import 'package:boohtacord_desktop/src/features/admin/audit/filter.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_audit_test_support.dart';

void main() {
  test('filters loaded pages without another request and preserves pagination', () async {
    final calls = <String?>[];
    final first = auditEvent(id: 'first', type: 'CHANNEL_CREATED');
    final second = auditEvent(id: 'second', type: 'VOICE_LEASE_ISSUED');
    final controller = AdminAuditController(({String? before}) async {
      calls.add(before);
      return before == null
          ? AdminAuditPage(events: [first], nextCursor: 'cursor-2')
          : AdminAuditPage(events: [first, second]);
    });
    addTearDown(controller.dispose);

    await controller.load();
    controller.updateFilters(
      const AdminAuditFilters(scope: AdminAuditScope.voice),
    );
    expect(calls, [null]);
    expect(controller.filteredEvents, isEmpty);
    await controller.loadMore();
    expect(calls, [null, 'cursor-2']);
    expect(controller.events, [first, second]);
    expect(controller.filteredEvents, [second]);
  });

  test('tracks initial and pagination loading separately', () async {
    final initialPage = Completer<AdminAuditPage>();
    final nextPage = Completer<AdminAuditPage>();
    final controller = AdminAuditController(({String? before}) {
      return before == null ? initialPage.future : nextPage.future;
    });
    addTearDown(controller.dispose);

    final loading = controller.load();
    expect(controller.isLoadingInitial, isTrue);
    initialPage.complete(
      AdminAuditPage(events: [auditEvent(id: 'one', type: 'CHANNEL_CREATED')], nextCursor: 'next'),
    );
    await loading;
    final loadingMore = controller.loadMore();
    expect(controller.isLoadingMore, isTrue);
    nextPage.complete(const AdminAuditPage(events: []));
    await loadingMore;
    expect(controller.isLoading, isFalse);
    expect(controller.hasMore, isFalse);
  });

  test('keeps safe error state after failed pagination', () async {
    var calls = 0;
    final controller = AdminAuditController(({String? before}) async {
      calls++;
      if (before != null) throw StateError('private event payload');
      return AdminAuditPage(
        events: [auditEvent(id: 'one', type: 'CHANNEL_CREATED')],
        nextCursor: 'next',
      );
    });
    addTearDown(controller.dispose);
    await controller.load();
    await controller.loadMore();
    expect(controller.error, 'Не удалось загрузить журнал аудита.');
    expect(controller.error, isNot(contains('private event payload')));
    expect(controller.events, hasLength(1));
    expect(calls, 2);
  });

  test('does not notify listeners when a request finishes after dispose', () async {
    final page = Completer<AdminAuditPage>();
    final controller = AdminAuditController(({String? before}) => page.future);
    final loading = controller.load();
    controller.dispose();
    page.complete(const AdminAuditPage(events: []));
    await expectLater(loading, completes);
  });
}
