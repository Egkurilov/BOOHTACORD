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
          const Expanded(
            child: Text(
              'Поиск сообщений',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: GcColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
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
