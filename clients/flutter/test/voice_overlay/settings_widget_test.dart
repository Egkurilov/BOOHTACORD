import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/settings/model.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/preferences.dart';
import 'package:boohtacord_desktop/src/screens/voice_overlay_settings/component.dart';

void main() {
  test(
    'placement appearance hotkey and enabled persist only for their account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = await VoiceOverlayPreferences.open('first');
      const config = OverlayConfiguration(
        enabled: true,
        scale: 1.4,
        opacity: .5,
        x: .3,
        y: .2,
        monitor: 'DISPLAY2',
        hotkey: 119,
        modifiers: 3,
        maxParticipants: 4,
      );
      expect(await first.saveConfiguration(config), isTrue);
      expect(
        (await VoiceOverlayPreferences.open('first')).configuration.toJson(),
        config.toJson(),
      );
      expect(
        (await VoiceOverlayPreferences.open('second')).configuration.enabled,
        isFalse,
      );
    },
  );
  testWidgets(
    'actual settings dialog saves typed changes and remains usable after a conflict',
    (tester) async {
      OverlayConfiguration? saved;
      var allow = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => VoiceOverlaySettingsDialog(
                    initial: const OverlayConfiguration(),
                    save: (value) async {
                      saved = value;
                      return allow;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('overlay-scale')),
      );
      slider.onChanged!(1.5);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('save-overlay-settings')),
      );
      await tester.tap(find.byKey(const ValueKey('save-overlay-settings')));
      await tester.pumpAndSettle();
      expect(saved?.enabled, isTrue);
      expect(saved?.scale, 1.5);
      expect(
        find.textContaining('Не удалось применить настройки'),
        findsOneWidget,
      );
      allow = true;
      await tester.tap(find.byKey(const ValueKey('save-overlay-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceOverlaySettingsDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
