import 'package:http/http.dart' as http;

import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class MaintenanceApi {
  MaintenanceApi(this.transport);
  final ApiTransport transport;

  Future<http.StreamedResponse> maintenanceEvents() async {
    final request = http.Request('GET', transport.uri('/maintenance/events'))
      ..headers.addAll(transport.publicHeaders(accept: 'text/event-stream'));
    final response = await transport.client.send(request);
    if (response.statusCode != 200 ||
        response.headers['content-type']?.split(';').first.trim() !=
            'text/event-stream') {
      await response.stream.drain<void>();
      throw ApiFailure(
        'Не удалось подключиться к статусу обслуживания.',
        status: response.statusCode,
      );
    }
    return response;
  }
}
