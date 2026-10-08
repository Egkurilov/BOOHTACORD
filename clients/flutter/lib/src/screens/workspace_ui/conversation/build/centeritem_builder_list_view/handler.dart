import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension ConversationCenteritemBuilderListViewRenderer
    on WorkspaceConversationStateContext {
  Center renderConversationCenteritemBuilderListView() => Center(
    child: TextButton.icon(
      onPressed: widget.state.loadingOlderMessages ? null : workspaceLoadOlder,
      icon: widget.state.loadingOlderMessages
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.history),
      label: Text(
        widget.state.loadingOlderMessages
            ? 'Загружаем…'
            : 'Загрузить предыдущие сообщения',
      ),
    ),
  );
}
