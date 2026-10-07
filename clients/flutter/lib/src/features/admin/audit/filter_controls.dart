import 'package:flutter/material.dart';

import 'filter.dart';
import 'presentation.dart';

class AuditScopeFilter extends StatelessWidget {
  const AuditScopeFilter(this.filters, this.onChanged, {super.key});

  final AdminAuditFilters filters;
  final ValueChanged<AdminAuditFilters> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<AdminAuditScope>(
    key: const ValueKey('admin-audit-scope-filter'),
    isExpanded: true,
    initialValue: filters.scope,
    decoration: const InputDecoration(labelText: 'Область'),
    items: const [
      DropdownMenuItem(value: AdminAuditScope.all, child: Text('Все')),
      DropdownMenuItem(value: AdminAuditScope.admin, child: Text('Администрирование')),
      DropdownMenuItem(value: AdminAuditScope.voice, child: Text('Голос')),
    ],
    onChanged: (value) => onChanged(filters.copyWith(scope: value)),
  );
}

class AuditEventTypeFilter extends StatelessWidget {
  const AuditEventTypeFilter(this.filters, this.types, this.onChanged, {super.key});

  final AdminAuditFilters filters;
  final List<String> types;
  final ValueChanged<AdminAuditFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = types.contains(filters.eventType) ? filters.eventType : null;
    return DropdownButtonFormField<String?>(
      key: const ValueKey('admin-audit-type-filter'),
      isExpanded: true,
      initialValue: selected,
      decoration: const InputDecoration(labelText: 'Тип события'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Все типы')),
        for (final type in types)
          DropdownMenuItem(
            value: type,
            child: Text(auditEventTitle(type), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => onChanged(
        value == null
            ? filters.copyWith(clearEventType: true)
            : filters.copyWith(eventType: value),
      ),
    );
  }
}

class AuditActorFilter extends StatelessWidget {
  const AuditActorFilter(this.filters, this.actors, this.onChanged, {super.key});

  final AdminAuditFilters filters;
  final List<AuditActorOption> actors;
  final ValueChanged<AdminAuditFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = actors.any((item) => item.id == filters.actor)
        ? filters.actor
        : null;
    return DropdownButtonFormField<String?>(
      key: const ValueKey('admin-audit-actor-filter'),
      isExpanded: true,
      initialValue: selected,
      decoration: const InputDecoration(labelText: 'Инициатор'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Все инициаторы')),
        for (final actor in actors)
          DropdownMenuItem(
            value: actor.id,
            child: Text(actor.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => onChanged(
        value == null
            ? filters.copyWith(clearActor: true)
            : filters.copyWith(actor: value),
      ),
    );
  }
}
