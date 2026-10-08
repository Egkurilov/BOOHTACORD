import 'codec.dart';

class OverlayConfiguration {
  const OverlayConfiguration({
    this.enabled = false,
    this.scale = 1,
    this.opacity = .91,
    this.x = 1,
    this.y = 0,
    this.monitor = '',
    this.maxParticipants = 8,
    this.hotkey = 0,
    this.modifiers = 6,
  });
  final bool enabled;
  final double scale, opacity, x, y;
  final String monitor;
  final int maxParticipants, hotkey, modifiers;
  factory OverlayConfiguration.fromJson(Map<String, dynamic> value) =>
      decodeOverlayConfiguration(value);
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'scale': scale,
    'opacity': opacity,
    'x': x,
    'y': y,
    'monitor': monitor,
    'maxParticipants': maxParticipants,
    'hotkey': hotkey,
    'modifiers': modifiers,
  };
  OverlayConfiguration copyWith({
    bool? enabled,
    double? scale,
    double? opacity,
    double? x,
    double? y,
    String? monitor,
    int? maxParticipants,
    int? hotkey,
    int? modifiers,
  }) => OverlayConfiguration.fromJson({
    ...toJson(),
    'enabled': enabled ?? this.enabled,
    'scale': scale ?? this.scale,
    'opacity': opacity ?? this.opacity,
    'x': x ?? this.x,
    'y': y ?? this.y,
    'monitor': monitor ?? this.monitor,
    'maxParticipants': maxParticipants ?? this.maxParticipants,
    'hotkey': hotkey ?? this.hotkey,
    'modifiers': modifiers ?? this.modifiers,
  });
}
