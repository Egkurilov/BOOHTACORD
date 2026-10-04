class VoiceLevels {
  const VoiceLevels([this.participant = 100, this.screen = 100]);
  final int participant, screen;
  static VoiceLevels decode(Object? value) {
    if (value is! Map) return const VoiceLevels();
    return VoiceLevels(
      value['participant'] is num ? normalizeLevel(value['participant'] as num) : 100,
      value['screen'] is num ? normalizeLevel(value['screen'] as num) : 100,
    );
  }
  Map<String, int> toJson() => {'participant': participant, 'screen': screen};
}
int normalizeLevel(num value) => value.isFinite ? value.round().clamp(0, 200) : 100;
String deploymentOrigin(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty) return '';
  final port = uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80) ? ':${uri.port}' : '';
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host.toLowerCase();
  return '${uri.scheme}://$host$port';
}
