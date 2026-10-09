import 'package:flutter/material.dart';

import 'layout/presentation.dart';

/// Members presentation entry point. Account drafts and actions remain owned
/// by the screen controller; this widget only arranges the responsive surface.
class AdminMembersPanel extends StatelessWidget {
  const AdminMembersPanel({
    super.key,
    required this.headerPadding,
    required this.listPadding,
    required this.accountsCount,
    required this.loading,
    required this.accountsEmpty,
    required this.error,
    required this.filters,
    required this.resetCard,
    required this.conflictCards,
    required this.accountCards,
    required this.search,
    required this.roleFilter,
    required this.statusFilter,
    required this.resultsCount,
    required this.filtersActive,
    required this.onResetFilters,
    required this.cursor,
    required this.status,
    required this.loadingState,
    required this.onRefresh,
    required this.onLoadMore,
  });

  final EdgeInsets headerPadding;
  final EdgeInsets listPadding;
  final int accountsCount;
  final bool loading;
  final bool accountsEmpty;
  final String? error;
  final Widget filters;
  final Widget? resetCard;
  final List<Widget> conflictCards;
  final List<Widget> accountCards;
  final String search;
  final String roleFilter;
  final String statusFilter;
  final int resultsCount;
  final bool filtersActive;
  final VoidCallback onResetFilters;
  final String? cursor;
  final String? status;
  final Widget loadingState;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) => renderMembers(context);
}
