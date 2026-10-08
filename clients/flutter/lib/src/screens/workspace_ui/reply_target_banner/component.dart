import '../native_bindings.dart';

class WorkspaceReplyTargetBanner extends StatelessWidget {
  const WorkspaceReplyTargetBanner({
    super.key,
    required this.text,
    required this.onCancel,
  });
  final String text;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('reply-target-banner'),
    height: 41,
    child: Container(
      decoration: BoxDecoration(
        color: GcColors.surface,
        border: Border.all(color: GcColors.control),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: GcColors.text, fontSize: 12),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: GcColors.textSecondary,
              backgroundColor: GcColors.raised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GcRadii.sm),
              ),
            ),
            onPressed: onCancel,
            child: const Text('Отмена'),
          ),
        ],
      ),
    ),
  );
}
