class RealtimeEvent {
  const RealtimeEvent(this.id, this.kind, this.payload, {this.telemetry});
  final String id;
  final String? kind;
  final Map<String, dynamic> payload;
  final RealtimeTelemetry? telemetry;
}

class RealtimeTelemetry {
  const RealtimeTelemetry(this.reference, this.traceId, this.spanId);
  final String reference, traceId, spanId;
  static RealtimeTelemetry? parse(dynamic value) {
    if (value is! Map) return null;
    final reference = value['reference'],
        trace = value['trace_id'],
        span = value['span_id'];
    if (reference is! String ||
        reference.isEmpty ||
        reference.length > 512 ||
        trace is! String ||
        !RegExp(r'^(?!0{32}$)[0-9a-f]{32}$').hasMatch(trace) ||
        span is! String ||
        !RegExp(r'^(?!0{16}$)[0-9a-f]{16}$').hasMatch(span)) {
      return null;
    }
    return RealtimeTelemetry(reference, trace, span);
  }
}
