import '../audio_profile/generated.dart';
const _codecs = {'opus', 'red', 'pcmu', 'pcma', 'g722', 'cn', 'other'};
num? _number(Object? value, [num max = 9007199254740991]) =>
    value is num && value.isFinite && value >= 0 && value <= max ? value : null;
bool? _flag(Object? value) => value is bool ? value : null;
String? _codec(Object? value) => value is String && _codecs.contains(value) ? value : null;
Map<String, Object?> safeVoiceAudioReport(String profile, int? capBps,
    Map<String, Object?> capture, List<Map<String, Object?>> samples) {
  final safeCapture = <String, Object?>{};
  for (final key in ['sampleRate', 'channels', 'processingSampleRate', 'processingChannels']) {
    safeCapture[key] = _number(capture[key], key.contains('Rate') ? 192000 : 8);
  }
  for (final key in ['agc', 'aec', 'ns']) { safeCapture[key] = _flag(capture[key]); }
  if (capture['source'] == 'unavailable') safeCapture['source'] = 'unavailable';
  return {
    'profile': voiceAudioProfiles.any((entry) => entry['id'] == profile) ? profile : 'unknown',
    'capBps': _number(capBps, 512000), 'capture': safeCapture,
    'samples': samples.where((sample) => {'sender', 'receiver'}.contains(sample['direction'])).map((sample) {
      final safe = <String, Object?>{'direction': sample['direction'],
        'codec': _codec(sample['codec']), 'transportCodec': _codec(sample['transportCodec'])};
      for (final key in ['codecChannels', 'clockRate', 'bitrateBps', 'intervalMs', 'packets', 'jitterMs', 'lossPercent', 'concealedSamples', 'concealmentEvents']) {
        safe[key] = _number(sample[key]);
      }
      for (final key in ['red', 'dtx', 'fec', 'stereo']) { safe[key] = _flag(sample[key]); }
      return safe;
    }).toList(),
  };
}
