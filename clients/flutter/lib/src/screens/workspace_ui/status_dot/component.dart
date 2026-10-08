import '../native_bindings.dart';

class WorkspaceStatusDot extends StatelessWidget {
  const WorkspaceStatusDot({super.key, this.color = GcColors.success});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 7),
      ],
    ),
  );
}
