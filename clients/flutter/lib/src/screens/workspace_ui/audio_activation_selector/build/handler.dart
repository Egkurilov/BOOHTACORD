import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceAudioActivationSelectorStateBuildBinding
    on WorkspaceAudioActivationSelectorStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceAudioActivationSelectorStateBuild(context);
  }
}

extension WorkspaceAudioActivationSelectorStateBuildAction
    on WorkspaceAudioActivationSelectorStateContext {
  Widget executeWorkspaceAudioActivationSelectorStateBuild(
    BuildContext context,
  ) {
    final stacked =
        widget.compact &&
        MediaQuery.textScalerOf(context).scale(GcTypography.body) > 18;
    return Container(
      key: const ValueKey('audio-settings-activation-segment'),
      height: stacked
          ? null
          : widget.compact
          ? 50
          : 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GcColors.sidebar,
        border: Border.all(color: GcColors.borderSubtle),
        borderRadius: BorderRadius.circular(GcRadii.md),
      ),
      child: stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                workspaceChoice(
                  label: 'По голосу',
                  mode: AudioActivationMode.vad,
                  key: const ValueKey('audio-activation-vad'),
                  focusNode: workspaceVoiceFocusNode,
                  stacked: true,
                ),
                const SizedBox(height: 4),
                workspaceChoice(
                  label: 'По нажатию',
                  mode: AudioActivationMode.ptt,
                  key: const ValueKey('audio-activation-ptt'),
                  focusNode: workspacePushToTalkFocusNode,
                  stacked: true,
                ),
              ],
            )
          : Row(
              children: [
                workspaceChoice(
                  label: 'По голосу',
                  mode: AudioActivationMode.vad,
                  key: const ValueKey('audio-activation-vad'),
                  focusNode: workspaceVoiceFocusNode,
                  stacked: false,
                ),
                const SizedBox(width: 4),
                workspaceChoice(
                  label: 'По нажатию',
                  mode: AudioActivationMode.ptt,
                  key: const ValueKey('audio-activation-ptt'),
                  focusNode: workspacePushToTalkFocusNode,
                  stacked: false,
                ),
              ],
            ),
    );
  }
}
