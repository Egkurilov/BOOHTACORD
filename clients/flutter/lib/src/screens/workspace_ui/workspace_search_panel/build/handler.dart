import '../feedback/derive.dart';
import 'loading_notice/handler.dart';
import 'header_controls/handler.dart';
import 'search_input/handler.dart';
import 'results/handler.dart';
import 'scope_field/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateBuildBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceWorkspaceSearchPanelStateBuild(context);
  }
}

extension WorkspaceWorkspaceSearchPanelStateBuildAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  Widget executeWorkspaceWorkspaceSearchPanelStateBuild(BuildContext context) {
    final current = workspaceCurrentConversation();
    if (workspaceScope == 'current' && current == null) workspaceScope = 'all';
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final feedback = workspaceFeedback();
    final horizontalPadding = compact ? 16.0 : 20.0;
    final statusMessage = feedback.statusMessage;
    final emptyTitle = feedback.emptyTitle;
    final emptyMessage = feedback.emptyMessage;
    final emptyIcon = feedback.emptyIcon;
    final scopeField = renderWorkspaceSearchPanelScopeField(current);
    return Material(
      key: const ValueKey('workspace-search-panel'),
      color: GcColors.sidebar,
      child: Column(
        children: [
          renderWorkspaceSearchPanelHeaderControls(compact, horizontalPadding),
          renderWorkspaceSearchPanelSearchInput(
            horizontalPadding,
            compact,
            scopeField,
          ),
          if (workspaceError case final error?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: const TextStyle(color: GcColors.danger),
                  ),
                ),
              ),
            ),
          Semantics(
            key: const ValueKey('search-live-status'),
            liveRegion: true,
            label: statusMessage,
            child: const SizedBox.shrink(),
          ),
          if (workspaceLoading && workspaceResults.isNotEmpty)
            renderWorkspaceSearchPanelLoadingMore(
              horizontalPadding,
              statusMessage,
            ),
          if (workspaceSearched && workspaceResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ExcludeSemantics(
                  child: Text(
                    'Найдено ${workspaceResults.length} сообщения',
                    style: const TextStyle(
                      color: GcColors.muted,
                      fontSize: 12,
                      height: 16 / 12,
                    ),
                  ),
                ),
              ),
            ),
          if (workspaceNextCursor != null && !workspaceCanLoadMore)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Измените запрос или запустите поиск заново.',
                  style: TextStyle(color: GcColors.muted, fontSize: 12),
                ),
              ),
            ),
          renderWorkspaceSearchPanelResults(
            emptyTitle,
            emptyMessage,
            emptyIcon,
          ),
        ],
      ),
    );
  }
}
