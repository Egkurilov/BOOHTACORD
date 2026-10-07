part of 'panel.dart';

extension _RolePermissionLoading on RolePermissionsPanelState {
  Future<void> _load({required bool reset}) async {
    final before = Map<GuildPermission, bool>.of(baseline);
    final baseRevision = revision;
    setState(() {
      loading = true;
      error = null;
      status = null;
      if (!reset && conflictReview != null) {
        conflictReview = conflictReview!.withoutCurrent();
      }
    });
    try {
      final page = await widget.api.loadRolePolicies();
      final member = page.roles.firstWhere(
        (item) => item.role == GuildRole.member,
      );
      if (!mounted) return;
      final current = Map<GuildPermission, bool>.of(member.permissions);
      final proposed = Map<GuildPermission, bool>.of(draft);
      setState(() {
        roles = page.roles;
        if (reset) {
          revision = page.revision;
          baseline = current;
          draft = Map.of(current);
          conflictReview = null;
        } else if (conflictReview != null) {
          revision = page.revision;
          baseline = current;
          conflictReview = conflictReview!.withCurrent(current, revision);
        } else if (RolePermissionsPanelState._different(before, proposed)) {
          if (baseRevision != page.revision ||
              RolePermissionsPanelState._different(before, current)) {
            revision = page.revision;
            baseline = current;
            conflictReview = _PermissionConflict(
              before: before,
              current: current,
              proposed: proposed,
              revision: revision,
              ready: true,
            );
          }
        } else {
          revision = page.revision;
          baseline = current;
          draft = Map.of(current);
        }
      });
    } catch (cause) {
      if (mounted) setState(() => error = cause.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}
