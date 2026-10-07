import 'package:flutter/material.dart';

import '../../../models.dart';
import 'filter.dart';
import 'filter_fields.dart';

class AdminAuditFiltersPanel extends StatelessWidget {
  const AdminAuditFiltersPanel({
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
  Widget build(BuildContext context) {
    if (screenWidth >= 600) {
      return AuditFilterFields(
        filters: filters,
        events: events,
        screenWidth: screenWidth,
        onChanged: onChanged,
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('admin-audit-filter-open'),
        onPressed: () => _openSheet(context),
        icon: const Icon(Icons.filter_list),
        label: Text(filters.active ? 'Фильтры · настроены' : 'Фильтры'),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    var selected = filters;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          key: const ValueKey('admin-audit-filter-sheet'),
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Фильтры аудита', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                AuditFilterFields(
                  filters: selected,
                  events: events,
                  screenWidth: 360,
                  onChanged: (value) {
                    setSheetState(() => selected = value);
                    onChanged(value);
                  },
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Готово'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
