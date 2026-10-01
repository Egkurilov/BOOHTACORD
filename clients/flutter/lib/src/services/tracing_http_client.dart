import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:http/http.dart' as http;

import 'client_telemetry.dart';

class TracingHttpClient extends http.BaseClient {
  TracingHttpClient(this.inner);

  final http.Client inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!ClientTelemetry.enabled) return inner.send(request);
    final span = OTel.tracer().startSpan('api.request', kind: SpanKind.client);
    final method = request.method.toUpperCase();
    span.setStringAttribute(
      'http.request.method',
      const {
            'GET',
            'HEAD',
            'POST',
            'PUT',
            'PATCH',
            'DELETE',
            'OPTIONS',
          }.contains(method)
          ? method
          : 'OTHER',
    );
    ClientTelemetry.injectTraceHeaders(request.headers, span.spanContext);
    try {
      final response = await inner.send(request);
      span.setIntAttribute('http.response.status_code', response.statusCode);
      if (response.statusCode >= 500) span.setStatus(SpanStatusCode.Error);
      return response;
    } catch (_) {
      span.setStatus(SpanStatusCode.Error);
      rethrow;
    } finally {
      span.end();
    }
  }

  @override
  void close() => inner.close();
}
