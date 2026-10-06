import 'package:boohtacord_desktop/src/features/audio/microphone_controls/native.dart';
import 'package:boohtacord_desktop/src/features/audio/preferences/microphone.dart';
import 'package:boohtacord_desktop/src/widgets/microphone_controls/control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'AGC explains and preserves manual microphone gain until disabled',
    (tester) async {
      var agc = true;
      var settings = const MicrophoneSettings(microphoneGainPercent: 173);
      late StateSetter updateParent;
      final runtime = NativeMicrophoneControls(invoke: (_, _) async => null);
      addTearDown(runtime.dispose);

      Future<void> updateSettings({
        double? vadThresholdDb,
        double? microphoneGainPercent,
      }) async {
        updateParent(() {
          settings = settings.copyWith(
            vadThresholdDb: vadThresholdDb,
            microphoneGainPercent: microphoneGainPercent,
          );
        });
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                updateParent = setState;
                return MicrophoneControl(
                  settings: settings,
                  runtime: runtime,
                  onChanged: updateSettings,
                  sensitivity: false,
                  vad: true,
                  agc: agc,
                );
              },
            ),
          ),
        ),
      );

      final gainSliderFinder = find.byKey(
        const ValueKey('microphone-input-gain'),
      );
      var slider = tester.widget<Slider>(gainSliderFinder);
      expect(slider.value, 173);
      expect(slider.onChanged, isNull);
      expect(find.text('Громкость микрофона: 100%'), findsOneWidget);
      expect(
        find.text(
          'Управляется автоматически. Ручное значение сохранено: 173%.',
        ),
        findsOneWidget,
      );
      expect(
        slider.semanticFormatterCallback!(173),
        'Управляется автоматически',
      );

      updateParent(() => agc = false);
      await tester.pumpAndSettle();

      slider = tester.widget<Slider>(gainSliderFinder);
      expect(slider.value, 173);
      expect(slider.onChanged, isNotNull);
      expect(find.text('Громкость микрофона: 173%'), findsOneWidget);
      slider.onChanged!(145);
      await tester.pumpAndSettle();
      expect(settings.microphoneGainPercent, 145);
      slider = tester.widget<Slider>(gainSliderFinder);
      expect(slider.semanticFormatterCallback!(145), '145%');
      expect(tester.takeException(), isNull);
    },
  );
}
