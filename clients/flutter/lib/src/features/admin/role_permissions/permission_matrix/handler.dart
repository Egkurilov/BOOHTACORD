import 'groups.dart';
import '../native_bindings.dart';
import '../lifecycle/context.dart';

extension RolePermissionMatrixAction on RolePermissionsContext {
  Widget executeRenderPermissionMatrix(
    Map<GuildPermission, bool> values,
    double width,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (width >= 600)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text('Объект')),
              SizedBox(width: 140, child: Text('Создавать')),
              SizedBox(width: 140, child: Text('Удалять')),
            ],
          ),
        ),
      for (final group in permissionGroups)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: width < 600
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        group.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(group.hint, style: const TextStyle(fontSize: 12)),
                    renderPermissionTile(values, group.create),
                    renderPermissionTile(values, group.delete),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          title: Text(group.label),
                          subtitle: Text(group.hint),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: renderPermissionTile(values, group.create),
                    ),
                    SizedBox(
                      width: 140,
                      child: renderPermissionTile(values, group.delete),
                    ),
                  ],
                ),
        ),
    ],
  );
}
