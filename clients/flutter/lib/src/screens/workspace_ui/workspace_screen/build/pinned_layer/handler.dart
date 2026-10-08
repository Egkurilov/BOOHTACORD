import '../../../pinned_screen_mini_player/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderWorkspaceScreenPinnedLayerAction
    on WorkspaceScreenStateContext {
  Positioned renderWorkspaceScreenPinnedLayer(
    bool compact,
    BoxConstraints constraints,
    bool modalOverlayActive,
    bool pinnedMiniVisible,
    GuildChannel? activeVoiceChannel,
  ) => Positioned(
    right: compact ? 12 : 16,
    bottom: 16,
    child: SizedBox(
      width: (constraints.maxWidth - (compact ? 24 : 32))
          .clamp(0.0, 360.0)
          .toDouble(),
      child: ExcludeFocus(
        excluding: workspaceShowMobileSidebar || modalOverlayActive,
        child: ExcludeSemantics(
          excluding: workspaceShowMobileSidebar || modalOverlayActive,
          child: WorkspacePinnedScreenMiniPlayer(
            state: widget.state,
            identity: workspacePinnedScreenIdentity!,
            selectedIdentity: workspaceVisibleVoiceScreenIdentity,
            pinnedMiniVisible: pinnedMiniVisible,
            fullscreenSelection: workspaceFullscreenScreenSelection,
            onReturnToVoice: () =>
                unawaited(widget.state.selectChannel(activeVoiceChannel!)),
            onStopWatching: workspaceStopWatchingPinnedScreen,
          ),
        ),
      ),
    ),
  );
}
