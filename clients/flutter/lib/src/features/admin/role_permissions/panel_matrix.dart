part of 'panel.dart';

extension _RolePermissionMatrix on RolePermissionsPanelState {
  Widget _permissionMatrix(Map<GuildPermission, bool> values, double width) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (width >= 600) _matrixHeader(),
          for (final group in _permissionGroups)
            Container(
              key: ValueKey('permission-group:${group.label}'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: width < 600
                  ? _compactGroup(group, values)
                  : _wideGroup(group, values),
            ),
        ],
      );

  Widget _matrixHeader() => const Padding(
    padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(children: [
      Expanded(child: Text('Объект')),
      SizedBox(width: 140, child: Text('Создавать')),
      SizedBox(width: 140, child: Text('Удалять')),
    ]),
  );

  Widget _compactGroup(_PermissionGroup group, Map<GuildPermission, bool> values) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(
          leading: Icon(group.icon),
          title: Text(group.label),
          subtitle: Text(group.hint),
          dense: true,
        ),
        _permissionTile(values, group.create),
        _permissionTile(values, group.delete),
      ]);

  Widget _wideGroup(_PermissionGroup group, Map<GuildPermission, bool> values) => Row(
    children: [
      Expanded(child: ListTile(
        leading: Icon(group.icon),
        title: Text(group.label),
        subtitle: Text(group.hint),
      )),
      SizedBox(width: 140, child: _permissionTile(values, group.create)),
      SizedBox(width: 140, child: _permissionTile(values, group.delete)),
    ],
  );

  Widget _permissionTile(Map<GuildPermission, bool> values, GuildPermission key) =>
      CheckboxListTile(
        key: ValueKey('permission-checkbox:${key.wireName}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(_permissionLabels[key]!),
        value: values[key] ?? false,
        onChanged: role != GuildRole.member || selected?.editable != true || saving
            ? null
            : (value) => _setPermission(key, value ?? false),
      );

}

Widget _permissionValue(
  BuildContext context,
  bool enabled,
  String state,
  GuildPermission permission,
) => Text(
  enabled ? 'Разрешено' : 'Запрещено',
  key: ValueKey('conflict:${permission.wireName}:$state'),
  style: TextStyle(
    color: enabled ? Colors.green : Theme.of(context).colorScheme.error,
  ),
);

Widget _labeledValue(
  String label,
  bool enabled,
  String state,
  GuildPermission permission,
) => Chip(
  key: ValueKey('conflict:${permission.wireName}:$state'),
  label: Text('$label: ${enabled ? 'Разрешено' : 'Запрещено'}'),
  visualDensity: VisualDensity.compact,
);
