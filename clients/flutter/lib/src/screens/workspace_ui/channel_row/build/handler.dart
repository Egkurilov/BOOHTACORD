import 'channel_contents/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceChannelRowStateBuildBinding on WorkspaceChannelRowStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceChannelRowStateBuild(context);
  }
}

extension WorkspaceChannelRowStateBuildAction
    on WorkspaceChannelRowStateContext {
  Widget executeWorkspaceChannelRowStateBuild(BuildContext context) {
    final state = widget.state;
    final channel = widget.channel;
    final selected = widget.selected;
    final voiceConnected = widget.voiceConnected;
    final voiceParticipantCount = widget.voiceParticipantCount;
    final canManage = canDeleteChannel(state, channel);
    return FocusableActionDetector(
      key: ValueKey('workspace-channel-focus:${channel.id}'),
      enabled: canManage,
      onShowHoverHighlight: (value) =>
          workspaceMutateView(() => workspaceHovered = value),
      onShowFocusHighlight: (value) =>
          workspaceMutateView(() => workspaceFocused = value),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? GcColors.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: widget.onTap,
            onSecondaryTap: canManage
                ? () => deleteTopologyTarget(context, state, channel)
                : null,
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              key: ValueKey('workspace-channel-row:${channel.id}'),
              height:
                  MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint
                  ? GcLayout.touchTargetSize
                  : GcLayout.channelRowHeight,
              child: renderChannelRowChannelContents(
                voiceConnected,
                channel,
                selected,
                voiceParticipantCount,
                state,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
