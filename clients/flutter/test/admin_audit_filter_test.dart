import 'package:boohtacord_desktop/src/features/admin/audit/filter.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

AdminAuditEvent _event(
  String id,
  String type,
  DateTime at, {
  String? actorId,
  String? login,
}) => AdminAuditEvent(
  id: id,
  eventType: type,
  createdAt: at,
  actorUserId: actorId,
  actorLogin: login,
);

void main() {
  final events = [
    _event('voice', 'VOICE_LEASE_ISSUED', DateTime(2026, 10, 7, 10), actorId: 'a1'),
    _event('rename', 'CHANNEL_RENAMED', DateTime(2026, 10, 6, 10), actorId: 'a2'),
    _event('create', 'CHANNEL_CREATED', DateTime(2026, 10, 6, 9), actorId: 'a1'),
  ];

  test('filters all, admin and voice scopes over loaded events', () {
    expect(
      filterAdminAuditEvents(events, const AdminAuditFilters()),
      hasLength(3),
    );
    expect(
      filterAdminAuditEvents(
        events,
        const AdminAuditFilters(scope: AdminAuditScope.admin),
      ),
      hasLength(2),
    );
    expect(
      filterAdminAuditEvents(
        events,
        const AdminAuditFilters(scope: AdminAuditScope.voice),
      ),
      [events.first],
    );
  });

  test('date bounds include every event on the selected days', () {
    final dayEvents = [
      _event('start', 'X', DateTime(2026, 10, 6)),
      _event('end', 'X', DateTime(2026, 10, 6, 23, 59, 59, 999)),
      _event('before', 'X', DateTime(2026, 10, 5, 23, 59)),
      _event('after', 'X', DateTime(2026, 10, 7)),
    ];
    expect(
      filterAdminAuditEvents(
        dayEvents,
        AdminAuditFilters(
          from: DateTime(2026, 10, 6),
          to: DateTime(2026, 10, 6),
        ),
      ).map((event) => event.id),
      ['start', 'end'],
    );
  });

  test('combines event type and actor identity filters', () {
    expect(
      filterAdminAuditEvents(
        events,
        const AdminAuditFilters(eventType: 'CHANNEL_CREATED', actor: 'a1'),
      ),
      [events.last],
    );
    expect(
      filterAdminAuditEvents(
        events,
        const AdminAuditFilters(actor: 'system'),
      ),
      isEmpty,
    );
  });

  test('groups by local day newest first and appends pages without duplicates', () {
    final groups = groupAdminAuditByDay(events);
    expect(groups.keys.first, DateTime(2026, 10, 7));
    expect(groups[DateTime(2026, 10, 6)]!.map((event) => event.id), [
      'rename',
      'create',
    ]);
    expect(
      appendAdminAuditEvents(events, [events.last, _event('older', 'X', DateTime(2026, 10, 5))])
          .map((event) => event.id),
      ['voice', 'rename', 'create', 'older'],
    );
  });
}
