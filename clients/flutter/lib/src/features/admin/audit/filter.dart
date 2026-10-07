import '../../../models.dart';

enum AdminAuditScope { all, admin, voice }

class AdminAuditFilters {
  const AdminAuditFilters({
    this.scope = AdminAuditScope.all,
    this.from,
    this.to,
    this.eventType,
    this.actor,
  });

  final AdminAuditScope scope;
  final DateTime? from;
  final DateTime? to;
  final String? eventType;
  final String? actor;

  bool get active =>
      scope != AdminAuditScope.all ||
      from != null ||
      to != null ||
      eventType?.trim().isNotEmpty == true ||
      actor?.trim().isNotEmpty == true;

  AdminAuditFilters copyWith({
    AdminAuditScope? scope,
    DateTime? from,
    DateTime? to,
    String? eventType,
    String? actor,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearEventType = false,
    bool clearActor = false,
  }) =>
      AdminAuditFilters(
        scope: scope ?? this.scope,
        from: clearFrom ? null : from ?? this.from,
        to: clearTo ? null : to ?? this.to,
        eventType: clearEventType ? null : eventType ?? this.eventType,
        actor: clearActor ? null : actor ?? this.actor,
      );
}

List<AdminAuditEvent> filterAdminAuditEvents(
  List<AdminAuditEvent> events,
  AdminAuditFilters filters,
) {
  final actor = filters.actor?.trim();
  final type = filters.eventType?.trim();
  final from = filters.from == null
      ? null
      : DateTime(filters.from!.year, filters.from!.month, filters.from!.day);
  final toExclusive = filters.to == null
      ? null
      : DateTime(filters.to!.year, filters.to!.month, filters.to!.day + 1);
  return events
      .where((event) {
        final date = event.createdAt.toLocal();
        if (from != null && date.isBefore(from)) return false;
        if (toExclusive != null && !date.isBefore(toExclusive)) return false;
        if (type != null && type.isNotEmpty && event.eventType != type) {
          return false;
        }
        if (actor != null && actor.isNotEmpty &&
            (event.actorUserId ?? 'system') != actor) return false;
        if (filters.scope == AdminAuditScope.voice &&
            !event.eventType.startsWith('VOICE_')) {
          return false;
        }
        if (filters.scope == AdminAuditScope.admin &&
            event.eventType.startsWith('VOICE_')) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

List<AdminAuditEvent> appendAdminAuditEvents(
  List<AdminAuditEvent> current,
  List<AdminAuditEvent> next,
) {
  final ids = current.map((event) => event.id).toSet();
  return [
    ...current,
    for (final event in next)
      if (ids.add(event.id)) event,
  ];
}

Map<DateTime, List<AdminAuditEvent>> groupAdminAuditByDay(
  List<AdminAuditEvent> events,
) {
  final grouped = <DateTime, List<AdminAuditEvent>>{};
  for (final event in events) {
    final local = event.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    grouped.putIfAbsent(day, () => []).add(event);
  }
  final entries = grouped.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  return {
    for (final entry in entries)
      entry.key: (entry.value
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt))),
  };
}
