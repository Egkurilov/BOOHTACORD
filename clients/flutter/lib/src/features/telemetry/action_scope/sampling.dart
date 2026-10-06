import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

const telemetryConfigured = bool.fromEnvironment(
  'TELEMETRY_ENABLED',
  defaultValue: true,
);
Sampler configuredSampler() {
  const configured = String.fromEnvironment(
    'TRACE_SAMPLE_RATIO',
    defaultValue: '1',
  );
  final value = double.tryParse(configured);
  final ratio = value != null && value.isFinite && value >= 0 && value <= 1
      ? value
      : 1.0;
  return ParentBasedSampler(TraceIdRatioSampler(ratio));
}
