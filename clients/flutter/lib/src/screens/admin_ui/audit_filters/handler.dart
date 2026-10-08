import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminAuditFiltersBinding on AdminScreenStateContext {
  @override
  AdminAuditFilters get adminAuditFilters => executeAdminAuditFilters;
}

extension AdminScreenStateAdminAuditFiltersBindingAction
    on AdminScreenStateContext {
  AdminAuditFilters get executeAdminAuditFilters => AdminAuditFilters(
    scope: adminAuditScope,
    from: adminAuditFrom,
    to: adminAuditTo,
    eventType: adminAuditEventType,
    actor: adminAuditActor.text,
  );
}
