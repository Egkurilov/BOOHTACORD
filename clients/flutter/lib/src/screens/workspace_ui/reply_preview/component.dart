import '../native_bindings.dart';

class WorkspaceReplyPreview extends StatelessWidget {
  const WorkspaceReplyPreview({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: GcColors.accentText, width: 2)),
      ),
      child: Text(
        '↪ $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: GcColors.textSecondary, fontSize: 12),
      ),
    ),
  );
}
