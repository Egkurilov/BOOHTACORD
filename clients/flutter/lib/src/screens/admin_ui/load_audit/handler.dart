import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminLoadAuditBinding on AdminScreenStateContext {
  @override
  Future<void> adminLoadAudit({String? before}) =>
      executeAdminLoadAudit(before: before);
}

extension AdminScreenStateAdminLoadAuditBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminLoadAudit({String? before}) async {
    if (adminAuditLoading) return;
    adminMutateView(() {
      adminAuditLoading = true;
      adminAuditError = null;
    });
    try {
      final page = await widget.state.api.listAdminAudit(before: before);
      if (!mounted) return;
      adminMutateView(() {
        adminAuditEvents = before == null
            ? page.events
            : [...adminAuditEvents, ...page.events];
        adminAuditCursor = page.nextCursor;
      });
    } catch (cause) {
      if (!mounted) return;
      adminMutateView(() => adminAuditError = cause.toString());
    } finally {
      if (mounted) adminMutateView(() => adminAuditLoading = false);
    }
  }
}
