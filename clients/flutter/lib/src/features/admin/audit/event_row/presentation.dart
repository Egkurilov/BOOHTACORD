import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../panel.dart';
import '../../../../models.dart';
import '../event_labels/presentation.dart';

extension AuditEventRowPresentation on AdminAuditPanel {
  Widget renderAuditEvent(BuildContext context, AdminAuditEvent event) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final actorLabel = auditAccountLabel(
      event.actorDisplayName,
      event.actorLogin,
      fallback: event.actorUserId == null ? 'Система' : 'Удалённый аккаунт',
    );
    final target = event.targetUserId == null
        ? null
        : auditAccountLabel(
            event.targetDisplayName,
            event.targetLogin,
            fallback: 'Удалённый аккаунт',
          );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GcColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GcColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          key: PageStorageKey('admin-audit-expansion:${event.id}'),
          expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
              ? AnimationStyle.noAnimation
              : null,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            auditTitle(event.eventType),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Инициатор · $actorLabel',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (largeText)
                Text(
                  formatDate(event.createdAt),
                  style: const TextStyle(
                    color: GcColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          trailing: largeText
              ? null
              : Text(
                  formatDate(event.createdAt),
                  style: const TextStyle(
                    color: GcColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Инициатор · $actorLabel'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Тип · ${event.eventType}'),
            ),
            if (target != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Объект · $target'),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Время · ${formatDate(event.createdAt)}'),
            ),
          ],
        ),
      ),
    );
  }
}
