import '../lifecycle/context.dart';

mixin AdminScreenStateAdminAccountSummaryBinding on AdminScreenStateContext {
  @override
  String adminAccountSummary(String role, bool blocked) =>
      executeAdminAccountSummary(role, blocked);
}

extension AdminScreenStateAdminAccountSummaryBindingAction
    on AdminScreenStateContext {
  String executeAdminAccountSummary(String role, bool blocked) =>
      '${role == 'ADMINISTRATOR' ? 'Администратор' : 'Пользователь'}; '
      '${blocked ? 'заблокирован' : 'доступ открыт'}';
}
