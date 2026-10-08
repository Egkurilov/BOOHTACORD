import 'package:flutter/material.dart';

import '../panel.dart';
import '../filter.dart';

extension AuditFiltersPresentation on AdminAuditPanel {
  Widget renderAuditFilters(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final eventTypes = events.map((event) => event.eventType).toSet().toList()
      ..sort();
    return Padding(
      padding: listPadding.copyWith(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: compact ? double.infinity : 180,
            child: DropdownButtonFormField<AdminAuditScope>(
              key: const ValueKey('admin-audit-scope-filter'),
              isExpanded: true,
              initialValue: scope,
              decoration: const InputDecoration(labelText: 'Область'),
              items: const [
                DropdownMenuItem(
                  value: AdminAuditScope.all,
                  child: Text('Все события'),
                ),
                DropdownMenuItem(
                  value: AdminAuditScope.admin,
                  child: Text('Администрирование'),
                ),
                DropdownMenuItem(
                  value: AdminAuditScope.voice,
                  child: Text('Голос'),
                ),
              ],
              onChanged: (value) =>
                  onScopeChanged(value ?? AdminAuditScope.all),
            ),
          ),
          SizedBox(
            width: compact ? double.infinity : 220,
            child: TextField(
              controller: actor,
              decoration: const InputDecoration(labelText: 'Инициатор'),
              onChanged: (_) => onActorChanged(),
            ),
          ),
          SizedBox(
            width: compact ? double.infinity : 220,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('admin-audit-type:$eventType'),
              isExpanded: true,
              initialValue: eventType,
              decoration: const InputDecoration(labelText: 'Тип события'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Все типы'),
                ),
                for (final type in eventTypes)
                  DropdownMenuItem<String?>(value: type, child: Text(type)),
              ],
              onChanged: onEventTypeChanged,
            ),
          ),
          OutlinedButton(
            key: const ValueKey('admin-audit-from-filter'),
            onPressed: onPickFrom,
            child: Text(from == null ? 'От даты' : 'От ${formatDate(from!)}'),
          ),
          OutlinedButton(
            key: const ValueKey('admin-audit-to-filter'),
            onPressed: onPickTo,
            child: Text(to == null ? 'До даты' : 'До ${formatDate(to!)}'),
          ),
          if (filters.active)
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Сбросить фильтры'),
            ),
        ],
      ),
    );
  }
}
