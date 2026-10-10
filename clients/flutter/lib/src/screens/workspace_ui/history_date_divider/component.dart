import '../native_bindings.dart';

class WorkspaceHistoryDateDivider extends StatelessWidget {
  const WorkspaceHistoryDateDivider({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        const Expanded(child: Divider(height: 1, color: GcColors.border)),
        Flexible(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: GcColors.muted, fontSize: 12),
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1, color: GcColors.border)),
      ],
    ),
  );
}
