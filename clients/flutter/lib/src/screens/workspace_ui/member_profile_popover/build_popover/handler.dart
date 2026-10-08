import 'profile_content/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMemberProfilePopoverStateWorkspaceBuildPopoverBinding
    on WorkspaceMemberProfilePopoverStateContext {
  @override
  Widget workspaceBuildPopover(BuildContext context) {
    return executeWorkspaceMemberProfilePopoverStateWorkspaceBuildPopover(
      context,
    );
  }
}

extension WorkspaceMemberProfilePopoverStateWorkspaceBuildPopoverAction
    on WorkspaceMemberProfilePopoverStateContext {
  Widget executeWorkspaceMemberProfilePopoverStateWorkspaceBuildPopover(
    BuildContext context,
  ) {
    final participant = widget.state.voiceParticipantForAccount(
      widget.memberId,
    );
    final canMessage = workspaceMember?.id != widget.state.user?.accountId;
    final canKick =
        canMessage && participant != null && widget.state.user?.isAdmin == true;
    return Material(
      key: const ValueKey('member-profile-popover'),
      color: GcColors.raised,
      elevation: 8,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: GcColors.border),
        borderRadius: BorderRadius.circular(GcRadii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: widget.width,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: renderMemberProfilePopoverProfileContent(
            canMessage,
            canKick,
            participant,
            context,
          ),
        ),
      ),
    );
  }
}
