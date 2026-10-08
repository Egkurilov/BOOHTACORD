import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../panel.dart';

extension AuditHeadingPresentation on AdminAuditPanel {
  Widget renderAuditHeader() => Padding(
    padding: headerPadding,
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Аудит',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              Text(
                'События управления без содержимого сообщений',
                style: TextStyle(color: GcColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Обновить'),
        ),
      ],
    ),
  );
}
