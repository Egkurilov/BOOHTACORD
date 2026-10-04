import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/widgets/participant_volume/slider.dart';
import 'package:boohtacord_desktop/src/widgets/participant_volume/reset.dart';

void main() {
  testWidgets(
    'names the participant, exposes percentage and flushes interaction end',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var level = 100, flushed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParticipantVolumeSlider(
              name: 'Alice',
              volume: 100,
              onChanged: (value) => level = value,
              onChangeEnd: () => flushed++,
            ),
          ),
        ),
      );
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 0);
      expect(slider.max, 200);
      expect(slider.semanticFormatterCallback!(175), '175 процентов');
      expect(
        find.bySemanticsLabel('Громкость участника Alice'),
        findsOneWidget,
      );
      slider.onChanged!(175);
      await tester.pump();
      expect(level, 175);
      expect(find.text('Громкость · 175%'), findsOneWidget);
      tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(175);
      expect(flushed, 1);
      semantics.dispose();
    },
  );
  testWidgets(
    'reset is explicit and unavailable storage warning is nonblocking',
    (tester) async {
      var resets = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioVolumeReset(
              reset: () async {
                resets++;
              },
              warning: 'Настройки недоступны',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Сбросить настройки аудио'));
      await tester.pump();
      expect(resets, 1);
      expect(find.text('Настройки недоступны'), findsOneWidget);
    },
  );
}
