import 'dart:typed_data';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

typedef TraceSender = Future<void> Function(Uint8List body);

class ClientTelemetry {
  ClientTelemetry._();

  static bool enabled = false;

  static Map<String, String> currentTraceHeaders() {
    final headers = <String, String>{};
    final span = Context.current.spanContext;
    if (enabled && span != null) injectTraceHeaders(headers, span);
    return headers;
  }

  static String? currentTraceparent() => currentTraceHeaders()['traceparent'];

  static void injectTraceHeaders(
    Map<String, String> headers,
    SpanContext span,
  ) {
    if (!span.isValid) return;
    W3CTraceContextPropagator().inject(
      OTel.context(spanContext: span),
      headers,
      _HeaderSetter(headers),
    );
  }

  static Future<void> initialize(TraceSender send) async {
    if (enabled) return;
    await OTel.initialize(
      serviceName: 'boohtacord-flutter',
      tracerName: 'boohtacord/client',
      spanProcessor: BatchSpanProcessor(
        _RelayExporter(send),
        BatchSpanProcessorConfig(
          maxQueueSize: 512,
          maxExportBatchSize: 32,
          scheduleDelay: const Duration(seconds: 5),
        ),
      ),
      enableMetrics: false,
      enableLogs: false,
      detectPlatformResources: false,
    );
    enabled = true;
  }

  static Future<T> trace<T>(
    String name,
    Future<T> Function() action, {
    bool Function()? failed,
  }) async {
    if (!enabled) return action();
    final span = OTel.tracer().startSpan(name, kind: SpanKind.client);
    span.addEventNow('app.client.$name.started');
    try {
      final result = await OTel.context(spanContext: span.spanContext)
          .run(action);
      if (failed?.call() ?? false) {
        span.setStatus(SpanStatusCode.Error);
        span.addEventNow('app.client.$name.failed');
      } else {
        span.addEventNow('app.client.$name.completed');
      }
      return result;
    } catch (_) {
      span.setStatus(SpanStatusCode.Error);
      span.addEventNow('app.client.$name.failed');
      rethrow;
    } finally {
      span.end();
    }
  }
}

class _HeaderSetter extends TextMapSetter<String> {
  _HeaderSetter(this.headers);
  final Map<String, String> headers;
  @override
  void set(String key, String value) => headers[key] = value;
}

class _RelayExporter implements SpanExporter {
  _RelayExporter(this.send);

  final TraceSender send;

  @override
  Future<void> export(List<Span> spans) async {
    if (spans.isEmpty) return;
    final body = OtlpSpanTransformer.transformSpans(spans).writeToBuffer();
    await send(body).timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}
