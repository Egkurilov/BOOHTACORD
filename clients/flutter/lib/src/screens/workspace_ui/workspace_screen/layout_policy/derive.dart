import '../../native_bindings.dart';
import '../lifecycle/context.dart';

extension WorkspaceLayoutPolicy on WorkspaceScreenStateContext {
  ({
    bool compact,
    bool medium,
    bool wide,
    bool searchPanelActive,
    bool searchPanelModal,
    bool fullScreenSearch,
    bool modalOverlayActive,
    bool showPermanentMembers,
    bool showMemberToggle,
  })
  workspaceLayout(double width) {
    final compact = width < GcLayout.mobileBreakpoint;
    final medium = width >= GcLayout.mediumBreakpoint;
    final wide = width >= GcLayout.wideBreakpoint;
    final voiceStageWide =
        wide && widget.state.selectedChannel?.kind == ChannelKind.voice;
    final searchPanelActive =
        widget.state.workspacePanel == WorkspacePanel.search;
    final searchPanelModal = searchPanelActive && (!medium || voiceStageWide);
    final fullScreenSearch = searchPanelActive && width <= 720;
    final modalOverlayActive = workspaceShowMembersDrawer || searchPanelModal;
    final showPermanentMembers =
        medium &&
        widget.state.workspacePanel == WorkspacePanel.none &&
        widget.state.selectedDirectMessage == null &&
        !voiceStageWide;
    final showMemberToggle =
        !showPermanentMembers &&
        widget.state.workspacePanel == WorkspacePanel.none &&
        widget.state.selectedDirectMessage == null;
    return (
      compact: compact,
      medium: medium,
      wide: wide,
      searchPanelActive: searchPanelActive,
      searchPanelModal: searchPanelModal,
      fullScreenSearch: fullScreenSearch,
      modalOverlayActive: modalOverlayActive,
      showPermanentMembers: showPermanentMembers,
      showMemberToggle: showMemberToggle,
    );
  }
}
