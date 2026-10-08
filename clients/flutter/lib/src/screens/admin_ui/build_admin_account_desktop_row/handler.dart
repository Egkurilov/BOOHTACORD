import 'member_identity/handler.dart';
import 'member_controls/handler.dart';
import '../native_bindings.dart';
import '../lifecycle/context.dart';

mixin AdminScreenStateAdminBuildAdminAccountDesktopRowBinding
    on AdminScreenStateContext {
  @override
  Widget adminBuildAdminAccountDesktopRow(AdminAccount account) =>
      executeAdminBuildAdminAccountDesktopRow(account);
}

extension AdminScreenStateAdminBuildAdminAccountDesktopRowBindingAction
    on AdminScreenStateContext {
  Widget executeAdminBuildAdminAccountDesktopRow(AdminAccount account) {
    final draft = adminAccountDrafts[account.accountId];
    final busy = adminBusyAccountIds.contains(account.accountId);
    final sameVoiceParticipant =
        widget.state.voiceChannel != null &&
        widget.state.room?.remoteParticipants.values.any((participant) {
              return participant.metadata == 'account:${account.accountId}';
            }) ==
            true;
    final avatarColor = adminMemberAvatarColor(account.accountId);
    final initials = adminMemberInitials(account.displayName);
    return Container(
      key: ValueKey('admin-member-row:${account.accountId}'),
      constraints: const BoxConstraints(minHeight: 72),
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
      ),
      child: Row(
        children: [
          ...renderAdminMemberIdentity(avatarColor, initials, account),
          ...renderAdminMemberControls(
            account,
            draft,
            busy,
            sameVoiceParticipant,
          ),
        ],
      ),
    );
  }
}
