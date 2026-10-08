import '../native_bindings.dart';

abstract class AdminAuditContract {
  Future<void> adminLoadAudit({String? before});
  Future<void> adminPickAuditDate({required bool from});
  AdminAuditFilters get adminAuditFilters;
  Widget adminBuildAuditPanel();
  String adminAuditDate(DateTime date);
}
