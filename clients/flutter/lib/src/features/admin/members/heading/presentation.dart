import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../panel.dart';

extension AdminMembersHeading on AdminMembersPanel {
  Widget renderMembersHeading(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Участники $accountsCount',
          key: const ValueKey('admin-members-section-title'),
          style: const TextStyle(
            fontSize: 20,
            height: 28 / 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Text(
          'Роли и доступ к этой гильдии',
          style: TextStyle(color: GcColors.textSecondary, fontSize: 12),
        ),
      ],
    );
    final refresh = TextButton.icon(
      onPressed: loading ? null : onRefresh,
      icon: const Icon(Icons.refresh),
      label: const Text('Обновить'),
    );
    return Padding(
      padding: headerPadding,
      child: MediaQuery.textScalerOf(context).scale(14) > 21
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, refresh],
            )
          : Row(
              children: [
                Expanded(child: title),
                refresh,
              ],
            ),
    );
  }
}
