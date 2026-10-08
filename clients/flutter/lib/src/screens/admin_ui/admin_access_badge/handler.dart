import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminAdminAccessBadgeBinding on AdminScreenStateContext {
  @override
  Widget adminAccessBadge(bool blocked) =>
      executeAdminAdminAccessBadge(blocked);
}

extension AdminScreenStateAdminAdminAccessBadgeBindingAction
    on AdminScreenStateContext {
  Widget executeAdminAdminAccessBadge(bool blocked) => DecoratedBox(
    decoration: BoxDecoration(
      color: blocked ? GcColors.dangerBackground : GcColors.successBackground,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        blocked ? 'Заблокирован' : 'Активен',
        style: TextStyle(
          color: blocked ? GcColors.danger : GcColors.success,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
