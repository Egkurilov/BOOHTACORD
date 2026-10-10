import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminBuildMembersPanelBinding on AdminScreenStateContext {
  @override
  Widget adminBuildMembersPanel() => executeAdminBuildMembersPanel();
}

extension AdminScreenStateAdminBuildMembersPanelBindingAction
    on AdminScreenStateContext {
  Widget executeAdminBuildMembersPanel() => AdminMembersPanel(
    headerPadding: adminSectionHeaderPadding,
    listPadding: adminSectionListPadding,
    accountsCount: adminAccounts.length,
    loading: adminAccountsLoading,
    accountsEmpty: adminAccounts.isEmpty,
    error: adminAccountsError,
    filters: AdminMemberFilters(
      search: adminAccountSearch,
      role: adminAccountRoleFilter,
      status: adminAccountStatusFilter,
      onSearchChanged: () => adminMutateView(() {}),
      onRoleChanged: (value) =>
          adminMutateView(() => adminAccountRoleFilter = value),
      onStatusChanged: (value) =>
          adminMutateView(() => adminAccountStatusFilter = value),
    ),
    resetCard: adminResetLink == null ? null : adminBuildResetLinkCard(),
    conflictCards: [
      for (final entry in adminAccountConflicts.entries)
        adminBuildAccountConflictCard(entry.key, entry.value),
    ],
    accountCards: [
      for (final account in adminVisibleAdminAccounts)
        adminBuildAdminAccountCard(account),
    ],
    search: adminAccountSearch.text,
    roleFilter: adminAccountRoleFilter,
    statusFilter: adminAccountStatusFilter,
    resultsCount: adminVisibleAdminAccounts.length,
    filtersActive:
        adminAccountSearch.text.trim().isNotEmpty ||
        adminAccountRoleFilter != 'ALL' ||
        adminAccountStatusFilter != 'ALL',
    onResetFilters: () => adminMutateView(() {
      adminAccountSearch.clear();
      adminAccountRoleFilter = 'ALL';
      adminAccountStatusFilter = 'ALL';
    }),
    cursor: adminAccountCursor,
    status: adminAccountsStatus,
    loadingState: adminLoadingState(
      'Загружаем список участников…',
      'admin-members-loading',
    ),
    onRefresh: adminLoadAccounts,
    onLoadMore: () => adminLoadAccounts(cursor: adminAccountCursor),
  );
}
