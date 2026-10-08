import '../native_bindings.dart';

mixin AdminAuditFields {
  final adminAuditActor = TextEditingController();
  List<AdminAuditEvent> adminAuditEvents = const [];
  String? adminAuditCursor;
  bool adminAuditLoading = false;
  String? adminAuditError;
  AdminAuditScope adminAuditScope = AdminAuditScope.all;
  String? adminAuditEventType;
  DateTime? adminAuditFrom;
  DateTime? adminAuditTo;
}
