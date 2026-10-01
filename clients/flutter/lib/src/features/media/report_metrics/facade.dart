import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin ScreenMetricsReportFacade on ApiFacadeBase {
  late final _screenMetricsReport = ScreenMetricsReportApi(transport);

  Future<void> reportScreenShareMetrics(Map<String, Object> report) =>
      _screenMetricsReport.reportScreenShareMetrics(report);
}
