import 'package:http/http.dart' as http;

import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin MaintenanceFacade on ApiFacadeBase {
  late final _maintenance = MaintenanceApi(transport);

  Future<http.StreamedResponse> maintenanceEvents() =>
      transport.run(() => _maintenance.maintenanceEvents(), allowClosed: true);
}
