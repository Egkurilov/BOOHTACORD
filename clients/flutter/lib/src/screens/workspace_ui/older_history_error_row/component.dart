import '../native_bindings.dart';

class WorkspaceOlderHistoryErrorRow extends StatelessWidget {
  const WorkspaceOlderHistoryErrorRow({
    super.key,
    required this.message,
    required this.loading,
    required this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.alert,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF422830),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.error_outline,
                  color: GcColors.danger,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: GcColors.danger, fontSize: 13),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: loading ? null : onRetry,
              icon: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: const Text('Повторить'),
              style: TextButton.styleFrom(
                foregroundColor: GcColors.danger,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
