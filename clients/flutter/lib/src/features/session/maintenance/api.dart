import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class MaintenanceApi {
  MaintenanceApi(this.transport);
  final ApiTransport transport;

  Future<bool> maintenanceActive() async {
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/maintenance'),
        headers: transport.publicHeaders(),
      ),
    );
    if (data is! Map<String, dynamic> || data['active'] is! bool) {
      throw const ApiFailure('Сервер вернул некорректный статус обновления.');
    }
    return data['active'] as bool;
  }
}
