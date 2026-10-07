typedef JsonMap = Map<String, Object?>;

bool isMap(Object? value) => value is Map<String, Object?>;

bool exactKeys(JsonMap value, List<String> names) =>
    value.length == names.length && names.every(value.containsKey);

bool validText(Object? value, [int max = 256]) =>
    value is String && value.isNotEmpty && value.length <= max;

bool validWhole(Object? value, [int min = 0]) =>
    value is int && value >= min && value <= 9007199254740991;

bool validScope(Object? value) {
  if (!isMap(value)) return false;
  final scope = value as JsonMap;
  return exactKeys(scope, const [
        'origin_id', 'account_id', 'room_id', 'media_session_id',
        'publication_generation', 'operation_revision',
      ]) &&
      validText(scope['origin_id']) &&
      validText(scope['account_id']) &&
      validText(scope['room_id']) &&
      validText(scope['media_session_id']) &&
      validWhole(scope['publication_generation']) &&
      validWhole(scope['operation_revision']);
}

bool validEffectiveProfile(Object? value) {
  if (!isMap(value)) return false;
  final profile = value as JsonMap;
  final capture = profile['capture'];
  final encoding = profile['encoding'];
  if (!exactKeys(profile, const ['capture', 'encoding']) ||
      !isMap(capture) ||
      !isMap(encoding)) return false;
  final captureMap = capture as JsonMap;
  final encodingMap = encoding as JsonMap;
  final layers = encodingMap['layers'];
  return exactKeys(captureMap, const ['max_width', 'max_height', 'max_fps']) &&
      validWhole(captureMap['max_width'], 2) &&
      validWhole(captureMap['max_height'], 2) &&
      validWhole(captureMap['max_fps'], 1) &&
      exactKeys(encodingMap, const ['codec', 'layers']) &&
      (encodingMap['codec'] == null || validText(encodingMap['codec'], 32)) &&
      layers is List<Object?> && layers.isNotEmpty && layers.length <= 2 &&
      layers.every(validLayer);
}

bool validLayer(Object? value) {
  if (!isMap(value)) return false;
  final layer = value as JsonMap;
  final scale = layer['scale_down_by'];
  return exactKeys(layer, const [
        'rid', 'width', 'height', 'max_fps', 'max_bitrate_bps',
        'scale_down_by', 'active',
      ]) &&
      (layer['rid'] == null || validText(layer['rid'], 32)) &&
      validWhole(layer['width'], 2) && validWhole(layer['height'], 2) &&
      validWhole(layer['max_fps'], 1) &&
      validWhole(layer['max_bitrate_bps'], 1) &&
      scale is num && scale.isFinite && scale >= 1 &&
      layer['active'] is bool;
}

bool validCapabilities(Object? value) {
  if (!isMap(value)) return false;
  final caps = value as JsonMap;
  return exactKeys(caps, const [
        'live_update', 'republish_without_recapture', 'simulcast',
      ]) &&
      caps.values.every((entry) => entry is bool);
}
