import 'model.dart';

OverlayConfiguration decodeOverlayConfiguration(Map<String, dynamic> v) {
  double number(String key, double fallback, double min, double max) {
    final value = v[key];
    return value is num && value.isFinite
        ? value.toDouble().clamp(min, max)
        : fallback;
  }

  final key = v['hotkey'];
  final modifiers = v['modifiers'];
  final validModifiers = modifiers is int && modifiers > 0 && modifiers <= 15;
  final valid = key is int && key >= 112 && key <= 123 && validModifiers;
  final monitor = v['monitor'];
  return OverlayConfiguration(
    enabled: v['enabled'] == true,
    scale: number('scale', 1, .75, 2),
    opacity: number('opacity', .91, .25, 1),
    x: number('x', 1, 0, 1),
    y: number('y', 0, 0, 1),
    monitor: monitor is String && monitor.length <= 64 ? monitor : '',
    maxParticipants: number('maxParticipants', 8, 1, 12).toInt(),
    hotkey: valid ? key : 0,
    modifiers: validModifiers ? modifiers : 6,
  );
}
