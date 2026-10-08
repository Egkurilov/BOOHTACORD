import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceWorkspaceSearchPanel extends StatefulWidget {
  const WorkspaceWorkspaceSearchPanel({super.key, required this.state});
  final AppState state;

  @override
  State<WorkspaceWorkspaceSearchPanel> createState() =>
      WorkspaceWorkspaceSearchPanelState();
}

class WorkspaceWorkspaceSearchPanelState
    extends WorkspaceWorkspaceSearchPanelStateContext
    with
        WorkspaceWorkspaceSearchPanelStateInitStateBinding,
        WorkspaceWorkspaceSearchPanelStateWorkspaceQueryChangedBinding,
        WorkspaceWorkspaceSearchPanelStateWorkspaceCanLoadMoreBinding,
        WorkspaceWorkspaceSearchPanelStateWorkspaceCanSubmitBinding,
        WorkspaceWorkspaceSearchPanelStateStateBinding,
        WorkspaceWorkspaceSearchPanelStateWorkspaceCurrentConversationBinding,
        WorkspaceWorkspaceSearchPanelStateWorkspaceResetBinding,
        WorkspaceWorkspaceSearchPanelStateWorkspaceSearchBinding,
        WorkspaceWorkspaceSearchPanelStateWorkspaceConversationLabelBinding,
        WorkspaceWorkspaceSearchPanelStateDisposeBinding,
        WorkspaceWorkspaceSearchPanelStateBuildBinding {}
