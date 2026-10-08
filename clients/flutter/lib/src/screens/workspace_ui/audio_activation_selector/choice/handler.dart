import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceAudioActivationSelectorStateWorkspaceChoiceBinding
    on WorkspaceAudioActivationSelectorStateContext {
  @override
  Widget workspaceChoice({
    required String label,
    required AudioActivationMode mode,
    Key? key,
    required FocusNode focusNode,
    required bool stacked,
  }) {
    return executeWorkspaceAudioActivationSelectorStateWorkspaceChoice(
      label: label,
      mode: mode,
      key: key,
      focusNode: focusNode,
      stacked: stacked,
    );
  }
}

extension WorkspaceAudioActivationSelectorStateWorkspaceChoiceAction
    on WorkspaceAudioActivationSelectorStateContext {
  Widget executeWorkspaceAudioActivationSelectorStateWorkspaceChoice({
    required String label,
    required AudioActivationMode mode,
    Key? key,
    required FocusNode focusNode,
    required bool stacked,
  }) {
    final selected = widget.value == mode;
    final choice = Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: TextButton(
          key: key,
          focusNode: focusNode,
          onPressed: () => widget.onChanged(mode),
          style: TextButton.styleFrom(
            backgroundColor: selected ? GcColors.accent : Colors.transparent,
            foregroundColor: selected
                ? GcColors.onAccent
                : GcColors.textSecondary,
            minimumSize: Size(
              0,
              stacked
                  ? 44
                  : widget.compact
                  ? 40
                  : 36,
            ),
            padding: stacked
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
                : EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GcRadii.sm),
            ),
          ),
          child: workspaceLabel(label, selected, stacked),
        ),
      ),
    );
    return stacked
        ? SizedBox(width: double.infinity, child: choice)
        : Expanded(child: choice);
  }
}
