import 'dart:io';

import '../../../core/http/transport.dart';

class TelemetryExportApi {
  TelemetryExportApi(this.transport);
  final ApiTransport transport;

  Future<void> submitClientSpans(List<int> body) async {
    final response = await transport.raw.post(
      transport.uri('/telemetry/traces'),
      headers: {
        ...await transport.headers(),
        'content-type': 'application/x-protobuf',
        'x-client-platform': Platform.operatingSystem,
      },
      body: body,
    );
    if (response.statusCode != 202) {
      throw StateError('Telemetry export failed');
    }
  }
}
