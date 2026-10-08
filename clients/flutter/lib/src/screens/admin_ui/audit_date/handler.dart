import '../lifecycle/context.dart';

mixin AdminScreenStateAdminAuditDateBinding on AdminScreenStateContext {
  @override
  String adminAuditDate(DateTime date) => executeAdminAuditDate(date);
}

extension AdminScreenStateAdminAuditDateBindingAction
    on AdminScreenStateContext {
  String executeAdminAuditDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
