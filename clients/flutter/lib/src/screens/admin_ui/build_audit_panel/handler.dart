import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminBuildAuditPanelBinding on AdminScreenStateContext {
  @override
  Widget adminBuildAuditPanel() => executeAdminBuildAuditPanel();
}

extension AdminScreenStateAdminBuildAuditPanelBindingAction
    on AdminScreenStateContext {
  Widget executeAdminBuildAuditPanel() => AdminAuditPanel(
    headerPadding: adminSectionHeaderPadding,
    listPadding: adminSectionListPadding,
    events: adminAuditEvents,
    loading: adminAuditLoading,
    error: adminAuditError,
    cursor: adminAuditCursor,
    scope: adminAuditScope,
    eventType: adminAuditEventType,
    from: adminAuditFrom,
    to: adminAuditTo,
    actor: adminAuditActor,
    onRefresh: adminLoadAudit,
    onScopeChanged: (value) => adminMutateView(() => adminAuditScope = value),
    onEventTypeChanged: (value) =>
        adminMutateView(() => adminAuditEventType = value),
    onActorChanged: () => adminMutateView(() {}),
    onPickFrom: () => adminPickAuditDate(from: true),
    onPickTo: () => adminPickAuditDate(from: false),
    onClearFilters: () => adminMutateView(() {
      adminAuditScope = AdminAuditScope.all;
      adminAuditEventType = null;
      adminAuditActor.clear();
      adminAuditFrom = null;
      adminAuditTo = null;
    }),
    onLoadMore: () => adminLoadAudit(before: adminAuditCursor),
    filters: adminAuditFilters,
    formatDate: adminAuditDate,
  );
}
