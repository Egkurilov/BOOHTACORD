import '../../../models.dart';

class AdminMemberDraft {
  const AdminMemberDraft({required this.role, required this.blocked});
  factory AdminMemberDraft.fromAccount(AdminAccount account) =>
      AdminMemberDraft(role: account.role, blocked: account.blocked);
  final String role;
  final bool blocked;
  AdminMemberDraft copyWith({String? role, bool? blocked}) => AdminMemberDraft(
    role: role ?? this.role,
    blocked: blocked ?? this.blocked,
  );
  @override
  bool operator ==(Object other) =>
      other is AdminMemberDraft && role == other.role && blocked == other.blocked;
  @override
  int get hashCode => Object.hash(role, blocked);
}

class AdminMemberConflict {
  const AdminMemberConflict({required this.before, this.current});
  final AdminAccount before;
  final AdminAccount? current;
  AdminMemberConflict withCurrent(AdminAccount account) =>
      AdminMemberConflict(before: before, current: account);
}

class AdminMemberPage {
  const AdminMemberPage({required this.cursor, required this.accounts, this.nextCursor});
  final String? cursor;
  final List<AdminAccount> accounts;
  final String? nextCursor;
}

class AdminMemberResetResult {
  const AdminMemberResetResult(this.account, this.link);
  final AdminAccount account;
  final AdminPasswordResetLink link;
}
