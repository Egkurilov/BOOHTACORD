import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'controller.dart';
import 'empty_state.dart';
import 'event_details.dart';
import 'presentation.dart';

class AdminAuditEventList extends StatelessWidget {
  const AdminAuditEventList({super.key, required this.controller});

  final AdminAuditController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingInitial) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Semantics(
              key: const ValueKey('admin-audit-loading'),
              liveRegion: true,
              child: Text('Загружаем аудит…'),
            ),
          ],
        ),
      );
    }
    if (controller.events.isEmpty && controller.error != null) {
      return _message(
        controller.error!,
        action: OutlinedButton(
          key: const ValueKey('admin-audit-retry'),
          onPressed: controller.isLoading ? null : controller.refresh,
          child: const Text('Повторить'),
        ),
      );
    }
    if (controller.events.isEmpty && controller.hasLoaded) {
      return const Center(child: Text('Записей пока нет.'));
    }
    if (controller.filteredEvents.isEmpty && controller.filters.active) {
      return AdminAuditNoMatches(controller: controller);
    }
    return ListView(
      key: const ValueKey('admin-audit-events'),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        for (final group in controller.groupedEvents.entries) ...[
          Semantics(
            key: ValueKey('admin-audit-day:${auditDayKey(group.key)}'),
            container: true,
            header: true,
            label: auditDayLabel(group.key),
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(
                auditDayLabel(group.key),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          for (final event in group.value) AdminAuditEventCard(event: event),
        ],
        if (controller.isLoadingMore)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          ),
        if (controller.error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              controller.error!,
              style: const TextStyle(color: GcColors.danger),
            ),
          ),
          TextButton(
            key: const ValueKey('admin-audit-retry-more'),
            onPressed: controller.isLoading ? null : controller.loadMore,
            child: const Text('Повторить загрузку'),
          ),
        ],
        if (controller.hasMore)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.isLoading ? null : controller.loadMore,
              child: const Text('Показать более ранние'),
            ),
          ),
      ],
    );
  }

  Widget _message(String label, {required Widget action}) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [Text(label), const SizedBox(height: 8), action],
    ),
  );
}
