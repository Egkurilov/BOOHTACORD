import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminAdminMemberAvatarColorBinding
    on AdminScreenStateContext {
  @override
  Color adminMemberAvatarColor(String id) =>
      executeAdminAdminMemberAvatarColor(id);
}

extension AdminScreenStateAdminAdminMemberAvatarColorBindingAction
    on AdminScreenStateContext {
  Color executeAdminAdminMemberAvatarColor(String id) {
    const colors = [
      GcColors.avatarBlue,
      GcColors.avatarGreen,
      GcColors.avatarViolet,
      GcColors.avatarOrange,
      GcColors.avatarGray,
    ];
    var hash = 2166136261;
    for (final rune in id.runes) {
      hash = ((hash ^ rune) * 16777619) & 0xFFFFFFFF;
    }
    return colors[hash % colors.length];
  }
}
