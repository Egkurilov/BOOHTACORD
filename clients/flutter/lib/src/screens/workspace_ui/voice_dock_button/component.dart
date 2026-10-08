import '../native_bindings.dart';

class WorkspaceVoiceDockButton extends StatelessWidget {
  const WorkspaceVoiceDockButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.danger,
    required this.onTap,
    this.compact = false,
    this.enabled = true,
    this.semanticsLabel,
    this.toggled,
  });
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;
  final bool compact;
  final bool enabled;
  final String? semanticsLabel;
  final bool? toggled;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    enabled: enabled,
    toggled: toggled,
    label: semanticsLabel ?? tooltip,
    onTap: enabled ? onTap : null,
    child: Tooltip(
      message: tooltip,
      child: ExcludeSemantics(
        child: Material(
          color: danger ? const Color(0x33422830) : GcColors.raised,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: compact ? 48 : 42,
              child: Icon(
                icon,
                size: 19,
                color: danger ? GcColors.danger : GcColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
