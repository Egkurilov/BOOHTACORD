import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin MaintenanceFacade on ApiFacadeBase {
  late final _maintenance = MaintenanceApi(transport);

  Future<bool> maintenanceActive() =>
      transport.run(() => _maintenance.maintenanceActive(), allowClosed: true);
}
