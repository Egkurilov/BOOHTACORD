import '../native_bindings.dart';

class WorkspaceEmptyConversation extends StatelessWidget {
  const WorkspaceEmptyConversation({super.key, required this.channel});
  final String channel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(36),
    child: Align(
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: GcColors.raised,
            child: Icon(Icons.tag_rounded, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            'Добро пожаловать в #$channel',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Это начало истории канала.',
            style: TextStyle(color: GcColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}
