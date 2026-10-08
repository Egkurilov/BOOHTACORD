import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceMemberProfilePopover extends StatefulWidget {
  const WorkspaceMemberProfilePopover({
    super.key,
    required this.state,
    required this.memberId,
    required this.width,
    required this.onClose,
    required this.onOpenDirectMessage,
  });

  final AppState state;
  final String memberId;
  final double width;
  final VoidCallback onClose;
  final ValueChanged<GuildMember> onOpenDirectMessage;

  @override
  State<WorkspaceMemberProfilePopover> createState() =>
      WorkspaceMemberProfilePopoverState();
}

class WorkspaceMemberProfilePopoverState
    extends WorkspaceMemberProfilePopoverStateContext
    with
        WorkspaceMemberProfilePopoverStateInitStateBinding,
        WorkspaceMemberProfilePopoverStateWorkspaceLoadBinding,
        WorkspaceMemberProfilePopoverStateWorkspaceKickBinding,
        WorkspaceMemberProfilePopoverStateWorkspaceBuildPopoverBinding,
        WorkspaceMemberProfilePopoverStateBuildBinding {}
