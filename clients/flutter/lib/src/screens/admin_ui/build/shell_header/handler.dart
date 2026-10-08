import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminShellHeaderAction on AdminScreenStateContext {
  List<Widget> renderAdminShellHeader(bool compact) => [
    AdminWorkspaceHeader(
      compact: compact,
      titleFocus: adminTitleFocus,
      onToggleNavigation: widget.onToggleNavigation,
      onClose:
          widget.onClose ??
          () => widget.state.toggleWorkspacePanel(WorkspacePanel.none),
    ),
  ];
}
