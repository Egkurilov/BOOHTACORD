import '../native_bindings.dart';
import '../account_draft/model.dart';

abstract class AdminAccountsContract {
  List<AdminAccount> get adminVisibleAdminAccounts;
  Future<void> adminLoadAccounts({String? cursor, bool acceptDrafts = false});
  Future<void> adminSaveAccount(AdminAccount account);
  Future<void> adminCreateResetLink(AdminAccount account);
  Future<void> adminKickVoiceParticipant(AdminAccount account);
  Future<void> adminCopyResetLink();
  Widget adminBuildMembersPanel();
  Widget adminBuildAdminAccountCard(AdminAccount account);
  Widget adminBuildAdminAccountDesktopRow(AdminAccount account);
  Widget adminBuildAdminAccountCompactCard(AdminAccount account);
  Widget adminBuildAccountConflictCard(
    String accountId,
    AdminAccountConflict conflict,
  );
  bool adminDraftChanged(AdminAccount baseline, AdminAccountDraft draft);
  String adminAccountSummary(String role, bool blocked);
  Color adminMemberAvatarColor(String id);
  String adminMemberInitials(String value);
  Widget adminBuildResetLinkCard();
}
