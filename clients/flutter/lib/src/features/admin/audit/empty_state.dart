import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'controller.dart';

class AdminAuditNoMatches extends StatelessWidget {
  const AdminAuditNoMatches({super.key, required this.controller});

  final AdminAuditController controller;

  @override
  Widget build(BuildContext context) {
    final canContinue = controller.hasMore;
    final action = controller.error != null
        ? TextButton(
            key: ValueKey(canContinue ? 'admin-audit-retry-more' : 'admin-audit-retry'),
            onPressed: controller.isLoading
                ? null
                : canContinue ? controller.loadMore : controller.refresh,
            child: Text(canContinue ? 'Повторить загрузку' : 'Повторить'),
          )
        : canContinue && !controller.isLoadingMore
        ? TextButton(
            onPressed: controller.isLoading ? null : controller.loadMore,
            child: const Text('Показать более ранние'),
          )
        : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Среди загруженных записей совпадений нет.',
            textAlign: TextAlign.center,
          ),
          if (controller.error != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  controller.error!,
                  style: const TextStyle(color: GcColors.danger),
                ),
              ),
            ),
          if (controller.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          if (action != null) action,
        ],
      ),
    );
  }
}
