import '../native_bindings.dart';

class WorkspaceChannelStateBadge extends StatelessWidget {
  const WorkspaceChannelStateBadge({
    super.key,
    required this.label,
    required this.semanticLabel,
  });
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: ExcludeSemantics(
      child: Container(
        constraints: const BoxConstraints(minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: GcColors.warningBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: GcColors.warning,
            fontSize: 11,
            height: 1.2,
          ),
        ),
      ),
    ),
  );
}
