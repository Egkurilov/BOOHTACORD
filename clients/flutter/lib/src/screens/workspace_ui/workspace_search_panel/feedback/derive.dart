import '../../native_bindings.dart';
import '../lifecycle/context.dart';

extension WorkspaceSearchFeedback on WorkspaceWorkspaceSearchPanelStateContext {
  ({
    String statusMessage,
    String emptyTitle,
    String emptyMessage,
    IconData emptyIcon,
  })
  workspaceFeedback() {
    final statusMessage = workspaceLoading
        ? 'Ищем сообщения…'
        : workspaceSearched
        ? workspaceResults.isEmpty
              ? 'Совпадений нет.'
              : 'Найдено ${workspaceResults.length} сообщения'
        : 'Введите запрос и нажмите Enter.';
    final emptyTitle = workspaceLoading
        ? 'Ищем сообщения…'
        : workspaceError != null
        ? 'Поиск временно недоступен'
        : workspaceSearched
        ? 'Совпадений нет.'
        : 'Найдите нужное сообщение';
    final emptyMessage = workspaceLoading
        ? ''
        : workspaceError != null
        ? 'Попробуйте запустить поиск ещё раз.'
        : workspaceSearched
        ? 'Измените запрос или область поиска и попробуйте снова.'
        : 'Введите запрос, чтобы найти сообщения в текстовых каналах и личных диалогах.';
    final emptyIcon = workspaceSearched
        ? Icons.search_off_rounded
        : workspaceError != null
        ? Icons.search_off_rounded
        : Icons.search_rounded;
    return (
      statusMessage: statusMessage,
      emptyTitle: emptyTitle,
      emptyMessage: emptyMessage,
      emptyIcon: emptyIcon,
    );
  }
}
