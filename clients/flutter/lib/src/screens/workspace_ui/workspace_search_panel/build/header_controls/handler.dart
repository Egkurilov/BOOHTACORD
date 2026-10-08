import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceSearchPanelHeaderControlsRenderer
    on WorkspaceWorkspaceSearchPanelStateContext {
  SizedBox renderWorkspaceSearchPanelHeaderControls(
    bool compact,
    double horizontalPadding,
  ) => SizedBox(
    key: const ValueKey('workspace-search-header'),
    height: compact ? 68 : 72,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? 0 : 4,
        compact ? 12 : horizontalPadding,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              pinsMode
                  ? 'Закреплённые'
                  : navigationMode
                  ? 'Каналы и люди'
                  : 'Поиск сообщений',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GcColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (workspaceCurrentConversation()?.direct == false)
            IconButton(
              tooltip: 'Закреплённые',
              onPressed: workspaceCurrentConversation()?.direct == false
                  ? () => workspaceMutateView(() {
                      pinsMode = !pinsMode;
                      navigationMode = false;
                    })
                  : null,
              icon: const Icon(Icons.push_pin_outlined, size: 20),
            ),
          IconButton(
            tooltip: navigationMode ? 'Поиск сообщений' : 'Каналы и люди',
            onPressed: () => workspaceMutateView(() {
              navigationMode = !navigationMode;
              pinsMode = false;
            }),
            icon: Icon(
              navigationMode ? Icons.chat_bubble_outline : Icons.people_outline,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Закрыть поиск',
            constraints: BoxConstraints.tightFor(
              width: compact ? 44 : 36,
              height: compact ? 44 : 36,
            ),
            padding: EdgeInsets.zero,
            onPressed: state.closeSearchPanel,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    ),
  );
}
