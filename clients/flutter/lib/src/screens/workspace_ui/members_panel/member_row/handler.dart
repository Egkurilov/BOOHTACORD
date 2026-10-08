import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateWorkspaceMemberRowBinding
    on WorkspaceMembersPanelStateContext {
  @override
  Widget workspaceMemberRow(BuildContext context, GuildMember member) {
    return executeWorkspaceMembersPanelStateWorkspaceMemberRow(context, member);
  }
}

extension WorkspaceMembersPanelStateWorkspaceMemberRowAction
    on WorkspaceMembersPanelStateContext {
  Widget executeWorkspaceMembersPanelStateWorkspaceMemberRow(
    BuildContext context,
    GuildMember member,
  ) {
    final tile = workspaceMemberTile(
      context,
      member,
      state.memberPresence(member),
    );
    if (workspaceProfileTriggerMemberId != member.id) return tile;
    return CompositedTransformTarget(
      link: workspaceProfileLink,
      child: Focus(focusNode: workspaceProfileTriggerFocus, child: tile),
    );
  }
}
