import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';
import 'model.dart';

class AdminReadinessApi {
  AdminReadinessApi(this.transport);
  final ApiTransport transport;

  Future<AdminReadiness> inspect() async {
    final response = await transport.client.get(
      transport.uri('/admin/readiness'),
      headers: await transport.headers(),
    );
    final data = await transport.checked(response, acceptedStatuses: {503});
    try {
      return AdminReadiness.fromJson(data);
    } on FormatException catch (error) {
      throw ApiFailure(error.message);
    } on Object {
      throw const ApiFailure('Сервер вернул некорректную готовность.');
    }
  }
}
