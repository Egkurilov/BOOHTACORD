import 'package:flutter/foundation.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import '../../../services/client_telemetry.dart';
import 'model.dart';
Map<String, String> audioTelemetryAttributes(String profile, Map<String, Object?> sample, String platform) {
  final attrs = <String, String>{'client.platform': platform, 'voice.audio.profile': profile, 'direction': sample['direction']! as String};
  void bucket(String key, Object? raw, int step, int max) {
    final value = statNumber(raw);
    if (value != null) attrs[key] = ((value / step).floor() * step).clamp(0, max).toString();
  }
  if (sample['codec'] is String) attrs['codec'] = sample['codec']! as String;
  bucket('channels', sample['codecChannels'], 1, 2);
  if (sample['clockRate'] == 48000) attrs['sample_rate'] = '48000';
  final bitrate = statNumber(sample['bitrateBps']);
  bucket('bitrate_kbps', bitrate == null ? null : bitrate / 1000, 8, 512);
  bucket('packets', sample['packets'], 10, 10000);
  bucket('jitter_ms', sample['jitterMs'], 5, 1000);
  bucket('loss_percent', sample['lossPercent'], 1, 100);
  bucket('concealed_samples', sample['concealedSamples'], 480, 480000);
  bucket('concealment_events', sample['concealmentEvents'], 1, 10000);
  for (final key in ['dtx', 'red', 'fec', 'stereo']) {
    if (sample[key] is bool) attrs[key] = sample[key].toString();
  }
  return attrs;
}
class VoiceAudioTelemetry {
  final _clock = Stopwatch()..start();
  int? _last;
  void submit(VoiceAudioDiagnostics snapshot) {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
    if (!ClientTelemetry.enabled || !{'web', 'android', 'ios', 'windows', 'macos'}.contains(platform)) return;
    final now = _clock.elapsedMilliseconds;
    if (_last != null && now - _last! < 10000) return;
    _last = now;
    final sender = snapshot.samples.where((sample) => sample['direction'] == 'sender').firstOrNull;
    final receivers = snapshot.samples.where((sample) => sample['direction'] == 'receiver').toList()
      ..sort((a, b) => (statNumber(b['lossPercent']) ?? -1).compareTo(statNumber(a['lossPercent']) ?? -1));
    for (final sample in [sender, receivers.firstOrNull]) {
      if (sample == null) continue;
      final span = OTel.tracer().startSpan('voice.audio.sample', kind: SpanKind.client);
      audioTelemetryAttributes(snapshot.profile, sample, platform).forEach(span.setStringAttribute);
      span.end();
    }
  }
}
