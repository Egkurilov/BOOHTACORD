import 'synchronize_screen_selection.dart';
import 'synchronize_pinned_publication.dart';
import 'restore_workspace_panel_focus.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceWorkspaceChangedBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceWorkspaceChanged() {
    executeWorkspaceScreenStateWorkspaceWorkspaceChanged();
  }
}

extension WorkspaceScreenStateWorkspaceWorkspaceChangedAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceWorkspaceChanged() {
    synchronizeScreenSelection();
    synchronizePinnedPublication();
    restoreWorkspacePanelFocus();
  }
}
