import '../native_bindings.dart';
import '../lifecycle/context.dart';

extension RoleHeadingAction on RolePermissionsContext {
  List<Widget> executeRenderRoleHeading() => [
    Row(
      children: [
        const Expanded(
          child: Text(
            'Роли и разрешения',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton.icon(
          onPressed: loading ? null : () => loadRoles(reset: false),
          icon: const Icon(Icons.refresh),
          label: const Text('Обновить'),
        ),
      ],
    ),
    SegmentedButton<GuildRole>(
      segments: const [
        ButtonSegment(value: GuildRole.member, label: Text('Пользователь')),
        ButtonSegment(
          value: GuildRole.administrator,
          label: Text('Администратор'),
        ),
      ],
      selected: {role},
      onSelectionChanged: (value) => unawaited(changeRole(value.single)),
    ),
    const SizedBox(height: 12),
  ];
}
