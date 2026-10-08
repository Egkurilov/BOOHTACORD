import '../lifecycle/context.dart';

mixin AdminScreenStateAdminAdminMemberInitialsBinding
    on AdminScreenStateContext {
  @override
  String adminMemberInitials(String value) =>
      executeAdminAdminMemberInitials(value);
}

extension AdminScreenStateAdminAdminMemberInitialsBindingAction
    on AdminScreenStateContext {
  String executeAdminAdminMemberInitials(String value) {
    final matches = RegExp(
      r'\p{L}',
      unicode: true,
    ).allMatches(value).take(2).map((match) => match.group(0)!).join();
    return matches.isEmpty ? 'У' : matches.toUpperCase();
  }
}
