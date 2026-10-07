part of 'panel.dart';

class _PermissionConflict {
  const _PermissionConflict({
    required this.before,
    required this.current,
    required this.proposed,
    required this.revision,
    this.ready = false,
  });

  final Map<GuildPermission, bool> before;
  final Map<GuildPermission, bool> current;
  final Map<GuildPermission, bool> proposed;
  final int revision;
  final bool ready;

  _PermissionConflict withCurrent(
    Map<GuildPermission, bool> values,
    int version,
  ) => _PermissionConflict(
    before: before,
    current: Map.of(values),
    proposed: proposed,
    revision: version,
    ready: true,
  );

  _PermissionConflict withProposed(
    Map<GuildPermission, bool> values,
    int version,
  ) => _PermissionConflict(
    before: before,
    current: current,
    proposed: Map.of(values),
    revision: version,
    ready: ready,
  );

  _PermissionConflict withoutCurrent() => _PermissionConflict(
    before: before,
    current: current,
    proposed: proposed,
    revision: revision,
  );
}
