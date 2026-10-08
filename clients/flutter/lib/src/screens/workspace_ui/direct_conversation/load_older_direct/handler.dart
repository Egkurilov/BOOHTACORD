import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceLoadOlderDirectBinding
    on WorkspaceDirectConversationStateContext {
  @override
  Future<void> workspaceLoadOlderDirect() {
    return executeWorkspaceDirectConversationStateWorkspaceLoadOlderDirect();
  }
}

extension WorkspaceDirectConversationStateWorkspaceLoadOlderDirectAction
    on WorkspaceDirectConversationStateContext {
  Future<void>
  executeWorkspaceDirectConversationStateWorkspaceLoadOlderDirect() async {
    if (!workspaceScroll.hasClients) return;
    final visibleAnchors = workspaceVisibleDirectMessageAnchors();
    final oldOffset = workspaceScroll.position.pixels;
    final oldExtent = workspaceScroll.position.maxScrollExtent;
    if (!await widget.state.loadOlderDirectMessages() || !mounted) return;
    void restoreAnchor(int attemptsRemaining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !workspaceScroll.hasClients) return;
        final position = workspaceScroll.position;
        final anchor = visibleAnchors
            .map((anchor) {
              final row = anchor.key.currentContext?.findRenderObject();
              return row is RenderBox && row.attached
                  ? (
                      top: anchor.top,
                      currentTop: row.localToGlobal(Offset.zero).dy,
                    )
                  : null;
            })
            .whereType<({double top, double currentTop})>()
            .firstOrNull;
        final target = anchor == null
            ? oldOffset + position.maxScrollExtent - oldExtent
            : position.pixels + anchor.currentTop - anchor.top;
        final clamped = target.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((position.pixels - clamped).abs() > 0.5) {
          position.jumpTo(clamped);
          if (attemptsRemaining > 1) restoreAnchor(attemptsRemaining - 1);
        }
      });
    }

    restoreAnchor(2);
  }
}
