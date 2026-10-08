import 'dart:convert';

import '../../../core/http/transport.dart';
import '../../telemetry/media_sample/record.dart';

class ScreenMetricsReportApi {
  ScreenMetricsReportApi(this.transport);
  final ApiTransport transport;

  Future<void> reportScreenShareMetrics(Map<String, Object> report) async {
    final session = transport.session.telemetry;
    final owner = session.snapshot();
    recordMediaSample(report, session, owner);
    await transport.checked(
      await transport.client.post(
        transport.uri('/voice/screen-metrics'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          ...report,
          if (owner.leaseId != null) 'voice_lease_id': owner.leaseId!,
        }),
      ),
    );
  }
}
