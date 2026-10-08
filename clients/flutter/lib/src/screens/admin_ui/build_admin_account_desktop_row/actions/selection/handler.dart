import '../../../native_bindings.dart';
import '../../../lifecycle/context.dart';
import '../../../account_draft/model.dart';
import '../../../voice_timeout/handler.dart';

extension AdminMemberActionSelection on AdminScreenStateContext {
  void adminSelectMemberAction(
    AdminAccount account,
    AdminAccountDraft? draft,
    String action,
  ) {
    switch (action) {
      case 'role':
        if (draft != null) {
          adminMutateView(
            () => draft.role = draft.role == 'ADMINISTRATOR'
                ? 'MEMBER'
                : 'ADMINISTRATOR',
          );
        }
        break;
      case 'blocked':
        if (draft != null) {
          adminMutateView(() => draft.blocked = !draft.blocked);
        }
        break;
      case 'save':
        adminSaveAccount(account);
        break;
      case 'reset':
        adminCreateResetLink(account);
        break;
      case 'timeout':
        adminOpenVoiceTimeout(account);
        break;
      case 'kick':
        adminKickVoiceParticipant(account);
        break;
    }
  }
}
