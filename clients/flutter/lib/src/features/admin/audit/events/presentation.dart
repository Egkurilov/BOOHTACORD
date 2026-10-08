import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../panel.dart';
import '../../../../models.dart';
import '../event_row/presentation.dart';
import '../event_labels/presentation.dart';

extension AuditEventsPresentation on AdminAuditPanel {
  List<Widget> renderAuditEvents(
    BuildContext context,
    Map<DateTime, List<AdminAuditEvent>> grouped,
  ) => <Widget>[
    for (final entry in grouped.entries) ...[
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          auditDayLabel(entry.key),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      for (final event in entry.value) renderAuditEvent(context, event),
    ],
    if (loading)
      Semantics(
        liveRegion: true,
        label: 'Обновляем аудит…',
        child: const Center(child: CircularProgressIndicator()),
      ),
    if (cursor != null)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: loading ? null : onLoadMore,
          child: const Text('Показать более ранние'),
        ),
      ),
    if (error != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Semantics(
          liveRegion: true,
          child: Text(error!, style: const TextStyle(color: GcColors.danger)),
        ),
      ),
  ];
}
