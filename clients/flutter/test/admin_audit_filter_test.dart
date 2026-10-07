import 'package:boohtacord_desktop/src/features/admin/audit/filter.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

AdminAuditEvent _event(String type, String login, DateTime createdAt) =>
    AdminAuditEvent(
      id: '$type-$login-${createdAt.day}',
      eventType: type,
      createdAt: createdAt,
      actorLogin: login,
    );

void main() {
  final events = [
    _event('VOICE_LEASE_ISSUED', 'alice', DateTime(2026, 10, 7, 10)),
    _event('CHANNEL_RENAMED', 'bob', DateTime(2026, 10, 6, 10)),
    _event('CHANNEL_CREATED', 'alice', DateTime(2026, 10, 6, 9)),
  ];

  test('filters by scope, actor and event type', () {
    expect(
      filterAdminAuditEvents(
        events,
        const AdminAuditFilters(scope: AdminAuditScope.voice),
      ),
      hasLength(1),
    );
    expect(
      filterAdminAuditEvents(
        events,
        const AdminAuditFilters(actor: 'ALICE', eventType: 'CHANNEL_CREATED'),
      ),
      hasLength(1),
    );
  });

  test('groups filtered events by local day in descending order', () {
    final groups = groupAdminAuditByDay(events);
    expect(groups.keys.first, DateTime(2026, 10, 7));
    expect(groups[DateTime(2026, 10, 6)], hasLength(2));
    expect(groups[DateTime(2026, 10, 6)]!.first.actorLogin, 'bob');
  });
}
