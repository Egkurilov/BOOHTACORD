import '../flow_contract/validate.dart';

Map<String, Object> mediaSampleFields(Map<String, Object> report) {
  final age = report['sample_age_ms'];
  final state = !validFlowField('app.sample.age_ms', age)
      ? 'unknown'
      : (age as num) > 15000
      ? 'stale'
      : 'fresh';
  final fields = <String, Object>{
    'app.media.sample_state': state,
    'app.media.direction': report['direction'] == 'receiver'
        ? 'receiver'
        : 'sender',
    'app.media.source': 'webrtc',
  };
  if (validFlowField('app.sample.age_ms', age)) {
    fields['app.sample.age_ms'] = age!;
  }
  if (state != 'fresh') return fields;
  const metrics = {
    'encoded_fps': 'encoded_fps',
    'decoded_fps': 'decoded_fps',
    'presented_fps': 'presented_fps',
    'rtt_ms': 'rtt_ms',
    'jitter_ms': 'jitter_ms',
    'packet_loss_percent': 'loss_percent',
    'target_fps': 'target_fps',
  };
  for (final entry in metrics.entries) {
    final value = report[entry.key], key = 'app.media.${entry.value}';
    if (validFlowField(key, value)) fields[key] = value!;
  }
  final bitrate = report['bitrate_kbps'];
  if (bitrate is num &&
      validFlowField('app.media.bitrate_bps', bitrate * 1000)) {
    fields['app.media.bitrate_bps'] = bitrate * 1000;
  }
  final window = report['packet_loss_window_ms'];
  if (validFlowField('app.sample.window_ms', window)) {
    fields['app.sample.window_ms'] = window!;
  }
  final adaptation = report['adaptation_reason'];
  if (validFlowField('app.media.adaptation_reason', adaptation)) {
    fields['app.media.adaptation_reason'] = adaptation!;
  }
  const extended = ['total_bitrate_kbps', 'selected_layer_bitrate_kbps', 'retransmitted_bitrate_kbps', 'encode_ms_per_frame', 'decode_ms_per_frame', 'jitter_buffer_ms_per_frame', 'nack_per_second', 'pli_per_second', 'fir_per_second', 'first_frame_ms', 'freeze_duration_ms', 'freeze_count', 'stats_window_ms', 'stats_source', 'presentation_source', 'collection_state'];
  for (final name in extended) {
    final value = report[name], key = 'app.media.$name';
    if (validFlowField(key, value)) fields[key] = value!;
  }
  return fields;
}

