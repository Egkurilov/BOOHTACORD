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
    this.dangerActive = false,
  });
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;
  final bool compact;
  final bool enabled;
  final String? semanticsLabel;
  final bool? toggled;
  final bool dangerActive;
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
          color: dangerActive
              ? GcColors.dangerSolid
              : danger
              ? GcColors.dangerBackground
              : GcColors.raised,
          shape: RoundedRectangleBorder(
            side: dangerActive
                ? const BorderSide(color: GcColors.danger, width: 1.5)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: compact ? 48 : 42,
              child: Icon(
                icon,
                size: 19,
                color: dangerActive
                    ? GcColors.onDanger
                    : danger
                    ? GcColors.danger
                    : GcColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
