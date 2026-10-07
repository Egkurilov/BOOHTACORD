import 'models.dart';

Map<String, Object> senderMeasurementFields(List<ScreenSenderLayerMetrics> layers) {
  final active = layers.where((layer) => layer.state == 'ACTIVE').toList()
    ..sort((a, b) => (b.width ?? 0) * (b.height ?? 0) - (a.width ?? 0) * (a.height ?? 0));
  final selected = active.isEmpty ? null : active.first;
  if (selected?.windowMs == null) { return {'stats_source': 'unsupported',
    'collection_state': layers.any((layer) => layer.state == 'STALE') ? 'stale' : layers.isEmpty ? 'unavailable' : layers.any((layer) => layer.state == 'UNKNOWN') ? 'unknown' : 'inactive'}; }
  final result = <String, Object>{'stats_source': 'webrtc_interval', 'stats_window_ms': selected!.windowMs!, 'collection_state': 'active'};
  void add(String key, double? value, double max) {
    if (value != null && value.isFinite && value >= 0 && value <= max) result[key] = value;
  }
  add('selected_layer_bitrate_kbps', selected.bitrateBps == null ? null : selected.bitrateBps! / 1000, 100000);
  add('retransmitted_bitrate_kbps', selected.retransmittedBps == null ? null : selected.retransmittedBps! / 1000, 100000);
  add('encode_ms_per_frame', selected.encodeMsPerFrame, 60000);
  add('nack_per_second', selected.nackPerSecond, 1000000);
  add('pli_per_second', selected.pliPerSecond, 1000000);
  add('fir_per_second', selected.firPerSecond, 1000000);
  if (layers.isNotEmpty && layers.every((layer) => layer.bitrateBps != null && layer.windowMs == selected.windowMs && layer.timestampMs == selected.timestampMs)) {
    add('total_bitrate_kbps', layers.fold<double>(0, (sum, layer) => sum + layer.bitrateBps!) / 1000, 100000);
  }
  return result;
}
