import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminBuildMediaPanelBinding on AdminScreenStateContext {
  @override
  Widget adminBuildMediaPanel() => executeAdminBuildMediaPanel();
}

extension AdminScreenStateAdminBuildMediaPanelBindingAction
    on AdminScreenStateContext {
  Widget executeAdminBuildMediaPanel() => AdminMediaMetricsPanel(
    headerPadding: adminSectionHeaderPadding,
    listPadding: adminSectionListPadding,
    loading: adminMediaLoading,
    samples: adminMediaSamples,
    error: adminMediaError,
    lastSuccessfulAt: adminMediaLastSuccessfulAt,
    lastSeenAt: adminMediaLastSeenAt,
    onRefresh: adminLoadMediaMetrics,
    formatDate: adminAuditDate,
  );
}
