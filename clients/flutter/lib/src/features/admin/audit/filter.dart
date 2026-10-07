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
}

List<AdminAuditEvent> filterAdminAuditEvents(
  List<AdminAuditEvent> events,
  AdminAuditFilters filters,
) {
  final actor = filters.actor?.trim().toLowerCase();
  final type = filters.eventType?.trim();
  return events
      .where((event) {
        final date = event.createdAt.toLocal();
        if (filters.from != null && date.isBefore(filters.from!)) return false;
        if (filters.to != null && date.isAfter(filters.to!)) return false;
        if (type != null && type.isNotEmpty && event.eventType != type) {
          return false;
        }
        if (actor != null && actor.isNotEmpty) {
          final haystack = [
            event.actorLogin,
            event.actorDisplayName,
            event.actorUserId,
          ].whereType<String>().join(' ').toLowerCase();
          if (!haystack.contains(actor)) return false;
        }
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
