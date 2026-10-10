import '../native_bindings.dart';
import '../lifecycle/context.dart';

extension RoleHeadingAction on RolePermissionsContext {
  List<Widget> executeRenderRoleHeading() {
    const title = Text(
      'Роли и разрешения',
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    );
    final refresh = TextButton.icon(
      onPressed: loading ? null : () => loadRoles(reset: false),
      icon: const Icon(Icons.refresh),
      label: const Text('Обновить'),
    );
    final compactLargeText =
        MediaQuery.sizeOf(context).width < 600 &&
        MediaQuery.textScalerOf(context).scale(17) > 24;
    return [
      if (compactLargeText)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            Align(alignment: Alignment.centerRight, child: refresh),
          ],
        )
      else
        Row(
          children: [
            const Expanded(child: title),
            refresh,
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
}
