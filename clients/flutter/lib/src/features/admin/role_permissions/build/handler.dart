import '../heading/handler.dart';
import '../actions/handler.dart';
import '../feedback/handler.dart';
import '../native_bindings.dart';
import '../lifecycle/context.dart';

extension RoleBuildAction on RolePermissionsContext {
  Widget executeBuild(BuildContext context) {
    final values = role == GuildRole.member
        ? draft
        : selected?.permissions ?? const <GuildPermission, bool>{};
    return PopScope(
      canPop: !dirty,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentInset = constraints.maxWidth < 1024 ? 0.0 : 24.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(contentInset, 0, contentInset, 24),
            children: [
              ...executeRenderRoleHeading(),
              if (loading && roles.isEmpty)
                Semantics(
                  liveRegion: true,
                  label: 'Загружаем разрешения ролей…',
                  child: const Center(child: CircularProgressIndicator()),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) =>
                      renderPermissionMatrix(values, constraints.maxWidth),
                ),
              ...executeRenderRoleActions(),
              ...executeRenderRoleFeedback(),
            ],
          );
        },
      ),
    );
  }
}
