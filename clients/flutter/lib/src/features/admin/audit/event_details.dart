import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';
import 'presentation.dart';

class AdminAuditEventCard extends StatelessWidget {
  const AdminAuditEventCard({super.key, required this.event});

  final AdminAuditEvent event;

  @override
  Widget build(BuildContext context) {
    final actor = auditActorLabel(event);
    final target = auditTargetLabel(event);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: GcColors.surface,
        border: Border.all(color: GcColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          key: ValueKey('admin-audit-details:${event.id}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              Text(actor, maxLines: 1, overflow: TextOverflow.ellipsis),
              const Text('→'),
              Text(
                auditEventTitle(event.eventType),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (target != null) ...[
                const Text('→'),
                Text(target, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
          subtitle: Text('Инициатор · $actor'),
          trailing: Text(
            auditClockTime(event.createdAt),
            style: const TextStyle(color: GcColors.textSecondary, fontSize: 11),
          ),
          children: [
            _detail('Тип', event.eventType),
            _detail('Время', auditDateTime(event.createdAt)),
            if (target != null) _detail('Объект', target),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('$label · $value'),
    ),
  );
}
