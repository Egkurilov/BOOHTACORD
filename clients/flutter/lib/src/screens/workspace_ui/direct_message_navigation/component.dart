import '../native_bindings.dart';

class WorkspaceDirectMessageNavigation extends StatelessWidget {
  const WorkspaceDirectMessageNavigation({
    super.key,
    required this.state,
    this.onSelected,
  });
  final AppState state;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                'ЛИЧНЫЕ СООБЩЕНИЯ',
                style: TextStyle(
                  color: GcColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          PopupMenuButton<DirectCandidate>(
            tooltip: 'Начать диалог',
            onSelected: (candidate) async {
              await state.createDirectConversation(candidate);
              onSelected?.call();
            },
            itemBuilder: (_) => state.directMessageCandidates
                .map(
                  (candidate) => PopupMenuItem(
                    value: candidate,
                    child: Text(candidate.displayName),
                  ),
                )
                .toList(growable: false),
            icon: const Icon(Icons.add_comment_outlined, size: 19),
          ),
        ],
      ),
      for (final conversation in state.directMessages)
        Material(
          color: Colors.transparent,
          child: ListTile(
            selected: state.selectedDirectMessage?.id == conversation.id,
            leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
            title: Text(
              conversation.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: conversation.unreadCount > 0
                ? Badge(label: Text('${conversation.unreadCount}'))
                : null,
            onTap: () async {
              await state.openDirectConversation(conversation);
              onSelected?.call();
            },
          ),
        ),
      if (state.directMessages.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Диалогов пока нет. Нажмите +, чтобы начать.',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
    ],
  );
}
