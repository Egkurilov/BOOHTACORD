import '../native_bindings.dart';
import '../lifecycle/context.dart';

extension RoleDefaultsAction on RolePermissionsContext {
  void executeLoadDefaults() => mutate(() {
    draft = {
      for (final key in GuildPermission.values) key: !deleteKeys.contains(key),
    };
    status = 'Значения по умолчанию загружены в черновик.';
  });
}
