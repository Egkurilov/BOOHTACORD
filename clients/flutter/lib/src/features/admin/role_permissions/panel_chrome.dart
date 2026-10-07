part of 'panel.dart';

extension _RolePermissionChrome on RolePermissionsPanelState {
  Widget _panelHeader() => Row(children: [
    const Expanded(
      child: Text(
        'Роли и разрешения',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    TextButton.icon(
      onPressed: loading ? null : () => _load(reset: false),
      icon: const Icon(Icons.refresh),
      label: const Text('Обновить'),
    ),
  ]);

  Widget _roleTabs() => SegmentedButton<GuildRole>(
    segments: const [
      ButtonSegment(
        value: GuildRole.member,
        label: Text('Пользователь', key: ValueKey('role-permissions-tab-member')),
        icon: Icon(Icons.person_outline),
      ),
      ButtonSegment(
        value: GuildRole.administrator,
        label: Text('Администратор', key: ValueKey('role-permissions-tab-administrator')),
        icon: Icon(Icons.admin_panel_settings_outlined),
      ),
    ],
    selected: {role},
    onSelectionChanged: loading || saving
        ? null
        : (values) => unawaited(_changeRole(values.single)),
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
  );

  Widget _administratorNote(double inset) => _notice(
    inset,
    icon: Icons.lock_outline,
    text: 'Разрешения администратора обязательны и не изменяются.',
  );

  Widget _deleteNotice(double inset) => _notice(
    inset,
    icon: Icons.info_outline,
    text: 'Разрешение удаления действует на любые каналы.',
  );

  Widget _notice(double inset, {required IconData icon, required String text}) =>
      Padding(
        padding: EdgeInsets.fromLTRB(inset, 8, inset, 0),
        child: Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ]),
          ),
        ),
      );

  Widget _dirtyNotice(double inset) => Padding(
    padding: EdgeInsets.fromLTRB(inset, 8, inset, 0),
    child: Semantics(
      liveRegion: hasPendingDraft,
      child: Text(
        hasPendingDraft ? 'Есть несохранённые изменения' : 'Изменения не внесены',
      ),
    ),
  );

  Widget _feedback(double inset) => Padding(
    padding: EdgeInsets.fromLTRB(inset, 6, inset, 0),
    child: Semantics(
      liveRegion: true,
      child: Text(
        status ?? error!,
        style: TextStyle(
          color: error == null ? Colors.green : Theme.of(context).colorScheme.error,
        ),
      ),
    ),
  );
}
