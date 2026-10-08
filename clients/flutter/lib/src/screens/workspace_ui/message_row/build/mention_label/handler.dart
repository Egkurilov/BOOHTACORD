import '../../../mention_display_name/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension MessageMentionLabel on WorkspaceMessageRowContext {
  Widget renderMessageMentionLabel() => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Text(
      'Упомянуты: ${message.mentionUserIds.map((id) => workspaceMentionDisplayName(state, id)).join(' ')}',
      style: const TextStyle(color: GcColors.muted, fontSize: 12),
    ),
  );
}
