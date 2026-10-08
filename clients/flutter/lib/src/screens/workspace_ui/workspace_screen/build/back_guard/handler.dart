import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderWorkspaceScreenBackGuardAction on WorkspaceScreenStateContext {
  PopScope<Object?> renderWorkspaceScreenBackGuard(Widget presentedContent) =>
      PopScope<Object?>(
        canPop:
            !workspaceShowMobileSidebar &&
            !workspaceShowMembersDrawer &&
            widget.state.workspacePanel != WorkspacePanel.search,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (workspaceShowMobileSidebar || workspaceShowMembersDrawer) {
            workspaceCloseDrawers();
          } else if (widget.state.workspacePanel == WorkspacePanel.search) {
            widget.state.closeSearchPanel();
          }
        },
        child: Padding(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.zero,
            child: presentedContent,
          ),
        ),
      );
}
