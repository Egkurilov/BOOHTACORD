import '../../../drawer_scrim/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceScreenSearchDrawerRenderer on WorkspaceScreenStateContext {
  Positioned renderWorkspaceScreenSearchDrawer(
    bool searchPanelModal,
    bool fullScreenSearch,
  ) => Positioned.fill(
    child: IgnorePointer(
      ignoring:
          !workspaceShowMobileSidebar &&
          !workspaceShowMembersDrawer &&
          (!searchPanelModal || fullScreenSearch),
      child: ExcludeSemantics(
        excluding:
            !workspaceShowMobileSidebar &&
            !workspaceShowMembersDrawer &&
            (!searchPanelModal || fullScreenSearch),
        child: AnimatedOpacity(
          opacity:
              workspaceShowMobileSidebar ||
                  workspaceShowMembersDrawer ||
                  (searchPanelModal && !fullScreenSearch)
              ? 1
              : 0,
          duration: GcMotion.slow,
          curve: GcMotion.standardCurve,
          child: WorkspaceDrawerScrim(onTap: workspaceCloseScrim),
        ),
      ),
    ),
  );
}
