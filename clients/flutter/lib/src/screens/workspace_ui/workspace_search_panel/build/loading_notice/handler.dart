import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderWorkspaceSearchPanelLoadingMoreAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  Padding renderWorkspaceSearchPanelLoadingMore(
    double horizontalPadding,
    String statusMessage,
  ) => Padding(
    padding: EdgeInsets.fromLTRB(horizontalPadding, 12, 16, 0),
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(
          statusMessage,
          style: const TextStyle(color: GcColors.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}
