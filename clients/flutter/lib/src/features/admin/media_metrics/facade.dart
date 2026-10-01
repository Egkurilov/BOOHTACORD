import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AdminMediaMetricsFacade on ApiFacadeBase {
  late final _adminMediaMetrics = AdminMediaMetricsApi(transport);

  Future<List<AdminScreenSample>> listAdminScreenMetrics() =>
      _adminMediaMetrics.listAdminScreenMetrics();
}
