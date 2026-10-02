import 'dart:async';

import 'package:boohtacord_desktop/src/features/voice/screen_viewer/audio_controls.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_viewer/audio_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a stream without screen audio has no audio controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceScreenAudioControls(
            showingLocalScreen: false,
            screenAudioAvailable: false,
            screenAudioVolume: null,
            screenAudioMuted: false,
            deafened: false,
            onToggleScreenAudio: null,
            onScreenAudioVolumeChanged: null,
          ),
        ),
      ),
    );

    expect(find.text('У демонстрации нет аудиодорожки.'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byTooltip('Выключить звук трансляции'), findsNothing);
  });

  testWidgets('screen audio exposes mute and a 0–200% volume control', (
    tester,
  ) async {
    var muted = false;
    var changedVolume = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: VoiceScreenAudioControls(
              showingLocalScreen: false,
              screenAudioAvailable: true,
              screenAudioVolume: 125,
              screenAudioMuted: muted,
              deafened: false,
              onToggleScreenAudio: () => setState(() => muted = !muted),
              onScreenAudioVolumeChanged: (value) => changedVolume = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Громкость аудиодорожки · 125%'), findsOneWidget);
    expect(find.byTooltip('Выключить звук трансляции'), findsOneWidget);
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('screen-share-audio-volume-slider')),
    );
    expect(slider.min, 0);
    expect(slider.max, 200);
    expect(slider.value, 125);
    expect(
      find.bySemanticsLabel('Громкость звука выбранной демонстрации'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Выключить звук трансляции'));
    await tester.pump();
    expect(muted, isTrue);
    expect(find.byTooltip('Включить звук трансляции'), findsOneWidget);

    slider.onChanged!(176);
    expect(changedVolume, 176);
  });

  testWidgets('deafen disables screen-share mute and gain controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceScreenAudioControls(
            showingLocalScreen: false,
            screenAudioAvailable: true,
            screenAudioVolume: 100,
            screenAudioMuted: false,
            deafened: true,
            onToggleScreenAudio: null,
            onScreenAudioVolumeChanged: null,
          ),
        ),
      ),
    );

    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<Slider>(
            find.byKey(const ValueKey('screen-share-audio-volume-slider')),
          )
          .onChanged,
      isNull,
    );
    expect(
      find.text(
        'Удалённый звук выключен; аудиодорожка сейчас не воспроизводится.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('local screen preview explains that it has no audio', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceScreenAudioControls(
            showingLocalScreen: true,
            screenAudioAvailable: false,
            screenAudioVolume: null,
            screenAudioMuted: false,
            deafened: false,
            onToggleScreenAudio: null,
            onScreenAudioVolumeChanged: null,
          ),
        ),
      ),
    );

    expect(
      find.text('Предпросмотр собственного экрана без звука.'),
      findsOneWidget,
    );
    expect(find.text('У демонстрации нет аудиодорожки.'), findsNothing);
  });

  testWidgets('enabling zero-volume audio restores gain without muting', (
    tester,
  ) async {
    var muted = false;
    var volume = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: VoiceScreenAudioControls(
              showingLocalScreen: false,
              screenAudioAvailable: true,
              screenAudioVolume: volume,
              screenAudioMuted: muted,
              deafened: false,
              onToggleScreenAudio: () => unawaited(
                toggleScreenAudioWithCallbacks(
                  volume: volume,
                  muted: muted,
                  setVolume: (value) async => setState(() => volume = value),
                  setMuted: (value) async => setState(() => muted = value),
                ),
              ),
              onScreenAudioVolumeChanged: (value) =>
                  setState(() => volume = value),
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Включить звук трансляции'), findsOneWidget);
    expect(find.text('Громкость аудиодорожки · 0%'), findsOneWidget);
    await tester.tap(find.byTooltip('Включить звук трансляции'));
    await tester.pump();

    expect(volume, 100);
    expect(muted, isFalse);
  });

  testWidgets('enabling zero-volume muted audio also clears mute', (
    tester,
  ) async {
    var muted = true;
    var volume = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: VoiceScreenAudioControls(
              showingLocalScreen: false,
              screenAudioAvailable: true,
              screenAudioVolume: volume,
              screenAudioMuted: muted,
              deafened: false,
              onToggleScreenAudio: () => unawaited(
                toggleScreenAudioWithCallbacks(
                  volume: volume,
                  muted: muted,
                  setVolume: (value) async => setState(() => volume = value),
                  setMuted: (value) async => setState(() => muted = value),
                ),
              ),
              onScreenAudioVolumeChanged: (value) =>
                  setState(() => volume = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Включить звук трансляции'));
    await tester.pump();

    expect(volume, 100);
    expect(muted, isFalse);
  });

  testWidgets('unavailable per-stream gain uses web-equivalent copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VoiceScreenAudioControls(
            showingLocalScreen: false,
            screenAudioAvailable: true,
            screenAudioVolume: null,
            screenAudioMuted: false,
            deafened: false,
            onToggleScreenAudio: _ignore,
            onScreenAudioVolumeChanged: null,
          ),
        ),
      ),
    );

    expect(
      find.text('Аудиодорожка есть; личная настройка громкости недоступна.'),
      findsOneWidget,
    );
  });
}

void _ignore() {}
