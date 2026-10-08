import 'package:flutter/material.dart';

import '../../../models.dart';
import 'filter.dart';
import 'layout/presentation.dart';

/// Presentation surface for the audit tab. Filtering and pagination state are
/// supplied by the workspace so changing tabs never recreates the draft state.
class AdminAuditPanel extends StatelessWidget {
  const AdminAuditPanel({
    super.key,
    required this.headerPadding,
    required this.listPadding,
    required this.events,
    required this.loading,
    required this.error,
    required this.cursor,
    required this.scope,
    required this.eventType,
    required this.from,
    required this.to,
    required this.actor,
    required this.onRefresh,
    required this.onScopeChanged,
    required this.onEventTypeChanged,
    required this.onActorChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearFilters,
    required this.onLoadMore,
    required this.filters,
    required this.formatDate,
  });

  final EdgeInsets headerPadding;
  final EdgeInsets listPadding;
  final List<AdminAuditEvent> events;
  final bool loading;
  final String? error;
  final String? cursor;
  final AdminAuditScope scope;
  final String? eventType;
  final DateTime? from;
  final DateTime? to;
  final TextEditingController actor;
  final VoidCallback onRefresh;
  final ValueChanged<AdminAuditScope> onScopeChanged;
  final ValueChanged<String?> onEventTypeChanged;
  final VoidCallback onActorChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearFilters;
  final VoidCallback onLoadMore;
  final AdminAuditFilters filters;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) => renderAuditPanel(context);
}
