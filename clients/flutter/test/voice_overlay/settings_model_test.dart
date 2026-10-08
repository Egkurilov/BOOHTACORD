import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/settings/model.dart';

void main() {
  test(
    'settings default opt-in off and round-trip all bounded account values',
    () {
      const defaults = OverlayConfiguration();
      expect(defaults.enabled, false);
      final chosen = defaults.copyWith(
        enabled: true,
        scale: 1.5,
        opacity: .7,
        x: .4,
        y: .6,
        monitor: 'DISPLAY2',
        maxParticipants: 4,
        hotkey: 119,
        modifiers: 6,
      );
      final restored = OverlayConfiguration.fromJson(chosen.toJson());
      expect(restored.toJson(), chosen.toJson());
    },
  );
  test('malformed settings fail closed and clamp numeric dimensions', () {
    final restored = OverlayConfiguration.fromJson({
      'scale': double.infinity,
      'opacity': -2,
      'x': 2,
      'y': -3,
      'hotkey': 1,
      'modifiers': 0,
      'maxParticipants': 99,
    });
    expect(restored.scale, 1);
    expect(restored.opacity, .25);
    expect(restored.x, 1);
    expect(restored.y, 0);
    expect(restored.hotkey, 0);
    expect(restored.maxParticipants, 12);
  });
}
