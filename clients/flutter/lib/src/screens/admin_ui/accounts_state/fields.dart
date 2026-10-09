import '../native_bindings.dart';
import '../account_draft/model.dart';

mixin AdminAccountsFields {
  final adminAccountSearch = TextEditingController();
  List<AdminAccount> adminAccounts = const [];
  String adminAccountRoleFilter = 'ALL';
  String adminAccountStatusFilter = 'ALL';
  String? adminAccountCursor;
  final Map<String, AdminAccountDraft> adminAccountDrafts = {};
  final Map<String, AdminAccount> adminAccountBaselines = {};
  final Map<String, AdminAccountConflict> adminAccountConflicts = {};
  final Map<String, FocusNode> adminAccountSaveFocusNodes = {};
  final Map<String, FocusNode> adminAccountActionFocusNodes = {};
  final Set<String> adminBusyAccountIds = {};
  bool adminAccountsLoading = false;
  String? adminAccountsError;
  String? adminAccountsStatus;
  AdminPasswordResetLink? adminResetLink;
  String? adminResetLogin;
}
