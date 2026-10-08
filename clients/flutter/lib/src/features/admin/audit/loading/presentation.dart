import 'package:flutter/material.dart';

import '../../../../theme.dart';
import '../panel.dart';

extension AuditLoadingPresentation on AdminAuditPanel {
  Widget renderAuditLoading(String message) => Center(
    child: Semantics(
      key: const ValueKey('admin-audit-loading'),
      liveRegion: true,
      label: message,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: GcColors.textSecondary),
      ),
    ),
  );

  Widget renderAuditExpandedLoading(String message) =>
      Expanded(child: renderAuditLoading(message));
}
