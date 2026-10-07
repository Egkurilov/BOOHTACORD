import 'package:flutter/material.dart';

import '../../../models.dart';
import 'filter.dart';
import 'filter_controls.dart';
import 'filter_dates.dart';
import 'presentation.dart';

class AuditFilterFields extends StatelessWidget {
  const AuditFilterFields({
    super.key,
    required this.filters,
    required this.events,
    required this.screenWidth,
    required this.onChanged,
  });

  final AdminAuditFilters filters;
  final List<AdminAuditEvent> events;
  final double screenWidth;
  final ValueChanged<AdminAuditFilters> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = screenWidth >= 1024 ? 5 : screenWidth >= 720 ? 3 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      final actors = auditActorOptions(events);
      final types = events.map((event) => event.eventType).toSet().toList()
        ..sort((a, b) => auditEventTitle(a).compareTo(auditEventTitle(b)));
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(width: width, child: AuditScopeFilter(filters, onChanged)),
          SizedBox(
            width: width,
            child: AuditDateFilter(
              date: filters.from,
              from: true,
              onChanged: (date) => onChanged(filters.copyWith(from: date)),
            ),
          ),
          SizedBox(
            width: width,
            child: AuditDateFilter(
              date: filters.to,
              from: false,
              onChanged: (date) => onChanged(filters.copyWith(to: date)),
            ),
          ),
          SizedBox(
            width: width,
            child: AuditEventTypeFilter(filters, types, onChanged),
          ),
          SizedBox(
            width: width,
            child: AuditActorFilter(filters, actors, onChanged),
          ),
          if (filters.active)
            TextButton(
              onPressed: () => onChanged(const AdminAuditFilters()),
              child: const Text('Сбросить фильтры'),
            ),
        ],
      );
    },
  );
}
