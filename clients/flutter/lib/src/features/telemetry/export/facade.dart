import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin TelemetryExportFacade on ApiFacadeBase {
  late final _telemetryExport = TelemetryExportApi(transport);

  Future<void> submitClientSpans(List<int> body) =>
      transport.run(() => _telemetryExport.submitClientSpans(body));
}
