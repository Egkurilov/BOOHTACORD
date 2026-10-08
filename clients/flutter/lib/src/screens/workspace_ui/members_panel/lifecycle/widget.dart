import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceMembersPanel extends StatefulWidget {
  const WorkspaceMembersPanel({super.key, required this.state, this.onClose});
  final AppState state;
  final VoidCallback? onClose;

  @override
  State<WorkspaceMembersPanel> createState() => WorkspaceMembersPanelState();
}

class WorkspaceMembersPanelState extends WorkspaceMembersPanelStateContext
    with
        WorkspaceMembersPanelStateStateBinding,
        WorkspaceMembersPanelStateOnCloseBinding,
        WorkspaceMembersPanelStateInitStateBinding,
        WorkspaceMembersPanelStateWorkspaceHandleHardwareKeyBinding,
        WorkspaceMembersPanelStateWorkspaceShowMemberProfileBinding,
        WorkspaceMembersPanelStateWorkspaceCloseMemberProfileBinding,
        WorkspaceMembersPanelStateDisposeBinding,
        WorkspaceMembersPanelStateBuildBinding,
        WorkspaceMembersPanelStateWorkspaceBuildPanelBinding,
        WorkspaceMembersPanelStateWorkspaceMemberRowBinding,
        WorkspaceMembersPanelStateWorkspaceMemberTileBinding {}
