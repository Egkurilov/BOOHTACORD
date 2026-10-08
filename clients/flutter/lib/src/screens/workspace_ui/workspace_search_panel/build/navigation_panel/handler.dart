import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';
import '../header_controls/handler.dart';
import '../../../../guild_quick_jump/component.dart';
import '../../../../guild_quick_jump/factory.dart';

extension QuickJumpNavigationRenderer
    on WorkspaceWorkspaceSearchPanelStateContext {
  Widget renderQuickJumpNavigation(bool compact) => Material(
    key: const ValueKey('workspace-search-panel'),
    color: GcColors.sidebar,
    child: Column(
      children: [
        renderWorkspaceSearchPanelHeaderControls(compact, compact ? 16 : 20),
        Expanded(
          child: GuildQuickJumpPanel(
            createOwner: () => guildQuickJumpOwner(state),
          ),
        ),
      ],
    ),
  );
}
