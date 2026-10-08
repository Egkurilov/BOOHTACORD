import 'popover_surface/handler.dart';
import '../../member_profile_popover/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateWorkspaceBuildPanelBinding
    on WorkspaceMembersPanelStateContext {
  @override
  Widget workspaceBuildPanel(BuildContext context) {
    return executeWorkspaceMembersPanelStateWorkspaceBuildPanel(context);
  }
}

extension WorkspaceMembersPanelStateWorkspaceBuildPanelAction
    on WorkspaceMembersPanelStateContext {
  Widget executeWorkspaceMembersPanelStateWorkspaceBuildPanel(
    BuildContext context,
  ) {
    final groups = [
      (
        title: 'В сети',
        members: state.members
            .where(
              (member) => state.memberPresence(member) == MemberPresence.online,
            )
            .toList(),
      ),
      (
        title: 'Не в сети',
        members: state.members
            .where(
              (member) =>
                  state.memberPresence(member) == MemberPresence.offline,
            )
            .toList(),
      ),
      (
        title: 'Статус неизвестен',
        members: state.members
            .where(
              (member) =>
                  state.memberPresence(member) == MemberPresence.unknown,
            )
            .toList(),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => OverlayPortal(
        controller: workspaceProfilePortal,
        overlayChildBuilder: (context) {
          final memberId = workspaceProfileMemberId;
          if (memberId == null) return const SizedBox.shrink();
          final popoverWidth = (constraints.maxWidth - GcSpacing.x8)
              .clamp(0.0, 288.0)
              .toDouble();
          return Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                workspaceCloseMemberProfile();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: CompositedTransformFollower(
              link: workspaceProfileLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(8, 0),
              child: UnconstrainedBox(
                alignment: Alignment.topRight,
                child: WorkspaceMemberProfilePopover(
                  key: ValueKey(memberId),
                  state: state,
                  memberId: memberId,
                  width: popoverWidth,
                  onClose: workspaceCloseMemberProfile,
                  onOpenDirectMessage: (member) async {
                    workspaceCloseMemberProfile();
                    await state.createDirectConversation(
                      DirectCandidate(
                        id: member.id,
                        displayName: member.displayName,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
        child: renderMembersPanelPopoverSurface(groups, context),
      ),
    );
  }
}
