import '../lifecycle/context.dart';
import '../native_bindings.dart';
import '../../admin_voice_timeout/dialog.dart';

extension AdminVoiceTimeoutAction on AdminScreenStateContext {
  Future<void> adminOpenVoiceTimeout(AdminAccount account) =>
      showAdminVoiceTimeout(
        context,
        api: widget.state.api,
        accountId: account.accountId,
        displayName: account.displayName,
        scopeChanges: widget.state,
      );
}
