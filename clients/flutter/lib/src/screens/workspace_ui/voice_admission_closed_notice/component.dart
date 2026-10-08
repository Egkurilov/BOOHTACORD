import '../error_banner/component.dart';
import '../native_bindings.dart';

class WorkspaceVoiceAdmissionClosedNotice extends StatelessWidget {
  const WorkspaceVoiceAdmissionClosedNotice({
    super.key,
    required this.error,
    this.onLeave,
  });

  final String? error;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          role: SemanticsRole.status,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF422830),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Вход в этот канал закрыт администратором. Отзыв media-доступа ещё подтверждается.',
              style: TextStyle(color: GcColors.danger, fontSize: 13),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          WorkspaceErrorBanner(message: error!),
        ],
        if (onLeave != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onLeave,
              child: const Text('Выйти из голосового канала'),
            ),
          ),
      ],
    ),
  );
}
