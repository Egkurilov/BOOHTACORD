import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminPickAuditDateBinding on AdminScreenStateContext {
  @override
  Future<void> adminPickAuditDate({required bool from}) =>
      executeAdminPickAuditDate(from: from);
}

extension AdminScreenStateAdminPickAuditDateBindingAction
    on AdminScreenStateContext {
  Future<void> executeAdminPickAuditDate({required bool from}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: (from ? adminAuditFrom : adminAuditTo) ?? DateTime.now(),
    );
    if (!mounted || selected == null) return;
    adminMutateView(() {
      if (from) {
        adminAuditFrom = DateTime(selected.year, selected.month, selected.day);
      } else {
        adminAuditTo = DateTime(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
          999,
        );
      }
    });
  }
}
