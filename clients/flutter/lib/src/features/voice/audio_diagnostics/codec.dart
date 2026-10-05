import 'model.dart';
String? codecName(Object? value) {
  if (value is! String) return null;
  final codec = value.toLowerCase().replaceFirst('audio/', '');
  return {'opus', 'red', 'pcmu', 'pcma', 'g722', 'cn'}.contains(codec) ? codec : 'other';
}
Map<String, Object?> audioCodec(Map<String, Object?> rtp, List<Map<String, Object?>> reports) {
  Map<String, Object?>? find(bool Function(Map<String, Object?>) match) {
    for (final report in reports) { if (match(report)) return report; }
    return null;
  }
  final transport = find((entry) => entry['id'] == rtp['codecId'] && entry['type'] == 'codec');
  var decoded = transport;
  final transportCodec = codecName(transport?['mimeType']);
  if (transportCodec == 'red') {
    final fmtp = transport?['sdpFmtpLine'];
    final payload = fmtp is String ? statNumber(fmtp.split('/').first) : null;
    decoded = find((entry) => entry['type'] == 'codec' && statNumber(entry['payloadType']) == payload && codecName(entry['mimeType']) == 'opus');
  }
  final fmtp = decoded?['sdpFmtpLine'];
  bool? flag(String key) {
    if (fmtp is! String) return null;
    for (final part in fmtp.split(';')) {
      final pair = part.trim().split('=');
      if (pair.length == 2 && pair[0] == key) return pair[1] == '1' ? true : pair[1] == '0' ? false : null;
    }
    return null;
  }
  return {
    'codec': codecName(decoded?['mimeType']), 'transportCodec': transportCodec,
    'codecChannels': statNumber(decoded?['channels']), 'clockRate': statNumber(decoded?['clockRate']),
    // An Opus stats entry does not prove the absence of redundant payloads.
    'red': transportCodec == 'red' ? true : null,
    'dtx': flag('usedtx'), 'fec': flag('useinbandfec'), 'stereo': flag('stereo'),
  };
}
