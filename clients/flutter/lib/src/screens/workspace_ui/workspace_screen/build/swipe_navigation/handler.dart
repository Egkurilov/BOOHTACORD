import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceScreenSwipeNavigationRenderer
    on WorkspaceScreenStateContext {
  AndroidSystemGestureExclusion renderWorkspaceScreenSwipeNavigation(
    bool drawerSwipeEnabled,
    bool showMemberToggle,
    MultiChildRenderObjectWidget shellContent,
  ) => AndroidSystemGestureExclusion(
    left: drawerSwipeEnabled,
    right: drawerSwipeEnabled && showMemberToggle,
    child: HorizontalSwipeRegion(
      enabled: drawerSwipeEnabled,
      canStart: (position, size) =>
          position.dx >= 0 &&
          position.dx <=
              (widget.state.selectedDirectMessage == null &&
                      widget.state.selectedChannel?.kind == ChannelKind.voice
                  ? size.width - 72
                  : 72),
      onSwipeRight: () {
        if (!workspaceTextInputFocused) workspaceToggleNavigation();
      },
      child: HorizontalSwipeRegion(
        enabled: drawerSwipeEnabled && showMemberToggle,
        canStart: (position, size) =>
            position.dx >= size.width - 72 && position.dx <= size.width,
        onSwipeLeft: () {
          if (!workspaceTextInputFocused) workspaceToggleMembers();
        },
        child: shellContent,
      ),
    ),
  );
}
