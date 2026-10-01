import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class AdminMediaMetricsApi {
  AdminMediaMetricsApi(this.transport);
  final ApiTransport transport;

  Future<List<AdminScreenSample>> listAdminScreenMetrics() async {
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/admin/screen-metrics'),
        headers: {...await transport.headers(), 'cache-control': 'no-store'},
      ),
    );
    if (data is! Map<String, dynamic> || data['samples'] is! List) {
      throw const ApiFailure('Сервер вернул некорректные показатели медиа.');
    }
    final samples = data['samples'] as List;
    if (samples.length > 16) {
      throw const ApiFailure('Сервер вернул некорректные показатели медиа.');
    }
    try {
      return samples
          .map(
            (value) =>
                AdminScreenSample.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on Object {
      throw const ApiFailure('Сервер вернул некорректные показатели медиа.');
    }
  }
}
