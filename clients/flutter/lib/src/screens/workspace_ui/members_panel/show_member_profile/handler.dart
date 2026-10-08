import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateWorkspaceShowMemberProfileBinding
    on WorkspaceMembersPanelStateContext {
  @override
  void workspaceShowMemberProfile(GuildMember member) {
    executeWorkspaceMembersPanelStateWorkspaceShowMemberProfile(member);
  }
}

extension WorkspaceMembersPanelStateWorkspaceShowMemberProfileAction
    on WorkspaceMembersPanelStateContext {
  void executeWorkspaceMembersPanelStateWorkspaceShowMemberProfile(
    GuildMember member,
  ) {
    workspaceProfileTriggerMemberId = member.id;
    workspaceProfileTriggerFocus.requestFocus();
    workspaceMutateView(() => workspaceProfileMemberId = member.id);
    workspaceProfilePortal.show();
  }
}
