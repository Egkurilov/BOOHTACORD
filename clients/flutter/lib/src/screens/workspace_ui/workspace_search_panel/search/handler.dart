import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateWorkspaceSearchBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  Future<void> workspaceSearch({String? before}) {
    return executeWorkspaceWorkspaceSearchPanelStateWorkspaceSearch(
      before: before,
    );
  }
}

extension WorkspaceWorkspaceSearchPanelStateWorkspaceSearchAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  Future<void> executeWorkspaceWorkspaceSearchPanelStateWorkspaceSearch({
    String? before,
  }) async {
    final query = (before == null ? workspaceQuery.text : workspaceActiveQuery)
        .trim();
    if (query.isEmpty) return;
    if (query.runes.length > 256) {
      workspaceMutateView(
        () => workspaceError = 'Запрос должен содержать до 256 символов.',
      );
      return;
    }
    final current = workspaceCurrentConversation();
    if (workspaceScope == 'current' && current == null) {
      workspaceMutateView(
        () => workspaceError = 'Выберите текстовый канал или личный диалог.',
      );
      return;
    }
    final sequence = ++workspaceSequence;
    workspaceMutateView(() {
      workspaceLoading = true;
      workspaceError = null;
    });
    try {
      final page = await state.api.searchMessages(
        query,
        channelId: workspaceScope == 'current' && current?.direct == false
            ? current!.id
            : null,
        directMessageId: workspaceScope == 'current' && current?.direct == true
            ? current!.id
            : null,
        before: before,
        limit: 20,
      );
      if (!mounted || sequence != workspaceSequence) return;
      workspaceMutateView(() {
        workspaceResults = before == null
            ? page.messages
            : [...workspaceResults, ...page.messages];
        workspaceNextCursor = page.nextCursor;
        workspaceActiveQuery = query;
        workspaceSearched = true;
      });
      if (before == null && workspaceRestoreScrollOffset > 0) {
        final offset = workspaceRestoreScrollOffset;
        workspaceRestoreScrollOffset = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !workspaceScroll.hasClients) return;
          final position = workspaceScroll.position;
          workspaceScroll.jumpTo(
            offset.clamp(0.0, position.maxScrollExtent).toDouble(),
          );
        });
      }
    } catch (cause) {
      if (mounted && sequence == workspaceSequence) {
        workspaceMutateView(() {
          workspaceError = cause is ApiFailure
              ? cause.message
              : 'Не удалось выполнить поиск сообщений.';
        });
      }
    } finally {
      if (mounted && sequence == workspaceSequence) {
        workspaceMutateView(() => workspaceLoading = false);
      }
    }
  }
}
