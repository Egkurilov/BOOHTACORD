import '../native_bindings.dart';

class WorkspaceVoiceDockPttButton extends StatefulWidget {
  const WorkspaceVoiceDockPttButton({super.key, required this.state});
  final AppState state;

  @override
  State<WorkspaceVoiceDockPttButton> createState() =>
      WorkspaceVoiceDockPttButtonState();
}

class WorkspaceVoiceDockPttButtonState
    extends State<WorkspaceVoiceDockPttButton> {
  int? workspacePointer;

  void workspaceStart() {
    if (widget.state.deafened ||
        (widget.state.voicePhase != VoicePhase.connected &&
            widget.state.voicePhase != VoicePhase.listener) ||
        widget.state.pushToTalkPressed) {
      return;
    }
    unawaited(widget.state.setPushToTalkPressed(true));
  }

  void workspaceStop() {
    workspacePointer = null;
    unawaited(widget.state.setPushToTalkPressed(false));
  }

  void workspaceRelease() {
    if (workspacePointer == null) return;
    workspaceStop();
  }

  @override
  void dispose() {
    workspaceRelease();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        !widget.state.deafened &&
        (widget.state.voicePhase == VoicePhase.connected ||
            widget.state.voicePhase == VoicePhase.listener);
    final pressed = widget.state.pushToTalkPressed;
    const label = 'Удерживайте, чтобы говорить';
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      customSemanticsActions: {
        if (enabled && !pressed)
          CustomSemanticsAction(label: 'Начать говорить'): workspaceStart,
        if (enabled && pressed)
          CustomSemanticsAction(label: 'Закончить говорить'): workspaceStop,
      },
      child: Tooltip(
        message: label,
        child: ExcludeSemantics(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: !enabled
                ? null
                : (event) {
                    if (workspacePointer != null ||
                        event.buttons != kPrimaryButton) {
                      return;
                    }
                    workspacePointer = event.pointer;
                    workspaceStart();
                  },
            onPointerUp: (event) {
              if (event.pointer == workspacePointer) workspaceRelease();
            },
            onPointerCancel: (event) {
              if (event.pointer == workspacePointer) workspaceRelease();
            },
            child: Material(
              color: pressed
                  ? GcColors.accent.withValues(alpha: 0.2)
                  : GcColors.raised,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: 48,
                child: Icon(
                  pressed ? Icons.mic : Icons.mic_none,
                  size: 19,
                  color: pressed ? GcColors.accent : GcColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
