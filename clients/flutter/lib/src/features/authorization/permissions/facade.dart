import '../../../core/http/facade_base.dart';
import 'api.dart';
import 'model.dart';

mixin PermissionsFacade on ApiFacadeBase {
  late final _permissionsApi = PermissionsApi(transport);
  Future<PermissionSnapshot> loadPermissions() => transport.run(_permissionsApi.load);
}
