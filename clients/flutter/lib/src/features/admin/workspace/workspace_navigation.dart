part of 'workspace.dart';

mixin _WorkspaceNavigation on _AdminWorkspaceBase {
  Future<void> _selectSection(AdminWorkspaceSection section) async {
    if (section == _selected) return;
    final editor = _roleKey.currentState;
    if (_selected == AdminWorkspaceSection.roles &&
        editor != null &&
        !await editor.confirmBeforeLeaving()) {
      return;
    }
    if (!mounted) return;
    setState(() => _selected = section);
    if (section == AdminWorkspaceSection.members &&
        !_members.hasLoadedDirectory) {
      unawaited(_members.load());
    }
    if (section == AdminWorkspaceSection.audit &&
        _audit.events.isEmpty &&
        !_audit.isLoading) {
      unawaited(_audit.load());
    }
  }

  Future<void> _closeWorkspace() async {
    final editor = _roleKey.currentState;
    if (editor != null && !await editor.confirmBeforeLeaving()) return;
    if (!mounted) return;
    (widget.onClose ??
            () => widget.state.toggleWorkspacePanel(WorkspacePanel.none))
        .call();
  }
}
