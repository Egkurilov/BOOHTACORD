import 'package:flutter/material.dart';

import '../../../theme.dart';

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
  final String? cursor;
  final String? status;
  final Widget loadingState;
  final VoidCallback onRefresh;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: headerPadding,
        child: Row(
          children: [
            Expanded(
              child: Column(
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
                    style: TextStyle(
                      color: GcColors.textSecondary,
                      fontSize: 12,
                    ),
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
      ),
      filters,
      if (loading && accountsEmpty)
        loadingState
      else if (!loading && accountsEmpty && error == null)
        const Expanded(child: Center(child: Text('Участников пока нет.')))
      else
        Expanded(
          child: ListView(
            key: ValueKey('admin-member-list:$search:$roleFilter'),
            padding: listPadding,
            children: [
              ?resetCard,
              ...conflictCards,
              if (!accountsEmpty && accountCards.isEmpty)
                const Text('По запросу участники не найдены.'),
              ...accountCards,
              if (loading) const Center(child: CircularProgressIndicator()),
              if (cursor != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: loading ? null : onLoadMore,
                    child: const Text('Загрузить ещё'),
                  ),
                ),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      status!,
                      style: const TextStyle(color: GcColors.success),
                    ),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: const TextStyle(color: GcColors.danger),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}
