import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceAudioActivationSelectorStateWorkspaceLabelBinding
    on WorkspaceAudioActivationSelectorStateContext {
  @override
  Widget workspaceLabel(String label, bool selected, bool stacked) {
    return executeWorkspaceAudioActivationSelectorStateWorkspaceLabel(
      label,
      selected,
      stacked,
    );
  }
}

extension WorkspaceAudioActivationSelectorStateWorkspaceLabelAction
    on WorkspaceAudioActivationSelectorStateContext {
  Widget executeWorkspaceAudioActivationSelectorStateWorkspaceLabel(
    String label,
    bool selected,
    bool stacked,
  ) => Text(
    label,
    maxLines: stacked ? null : 1,
    overflow: stacked ? TextOverflow.visible : TextOverflow.ellipsis,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: selected ? GcColors.onAccent : GcColors.textSecondary,
      fontSize: GcTypography.body,
      fontWeight: GcTypography.medium,
    ),
  );
}
