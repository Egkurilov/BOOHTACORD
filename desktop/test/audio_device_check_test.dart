import 'dart:async';

import 'package:boohtacord_desktop/src/services/audio_device_check.dart';
import 'package:boohtacord_desktop/src/widgets/audio_device_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolves the selected microphone by ID, then exact label', () {
    const selected = InputDevice(id: 'usb-1', label: 'USB Microphone');
    const available = [
      InputDevice(id: 'built-in', label: 'Built-in Microphone'),
      selected,
    ];

    expect(
      resolveInputDevice(
        selectedId: 'usb-1',
        selectedLabel: 'USB Microphone',
        available: available,
      ),
      selected,
    );
    expect(
      resolveInputDevice(
        selectedId: 'changed-id',
        selectedLabel: ' USB MICROPHONE ',
        available: available,
      ),
      selected,
    );
    const builtIn = InputDevice(id: '6', label: 'Built-in Microphone');
    expect(
      resolveInputDevice(
        selectedId: 'microphone-bottom',
        selectedLabel: 'Built-in Microphone (bottom)',
        available: const [builtIn],
        recorderDeviceId: '6',
      ),
      builtIn,
    );
    expect(
      resolveInputDevice(
        selectedId: 'microphone-bottom',
        selectedLabel: 'Built-in Microphone (bottom)',
        available: const [builtIn],
      ),
      builtIn,
    );
    expect(
      resolveInputDevice(
        selectedId: 'default',
        selectedLabel: null,
        available: available,
      ),
      isNull,
    );
    expect(
      () => resolveInputDevice(
        selectedId: 'missing',
        selectedLabel: 'Missing Microphone',
        available: available,
      ),
      throwsA(isA<AudioDeviceCheckFailure>()),
    );
  });

  test('maps microphone dBFS samples to a bounded linear meter', () {
    expect(amplitudePercentFromDb(double.negativeInfinity), 0);
    expect(amplitudePercentFromDb(-100), 0);
    expect(amplitudePercentFromDb(-20), closeTo(0.1, 0.001));
    expect(amplitudePercentFromDb(0), 1);
    expect(amplitudePercentFromDb(10), 1);
  });

  test('keeps Android communication output on its AudioManager route', () {
    expect(
      resolvePlaybackDevice(
        selectedId: 'android-communication-route:21',
        selectedLabel: 'Динамик телефона',
        available: const [],
      ),
      isNull,
    );
    expect(
      resolvePlaybackDevice(
        selectedId: 'android-usb-route:21',
        selectedLabel: 'USB headset',
        available: const [],
      ),
      isNull,
    );
  });

  testWidgets('checks the microphone level and selected output locally', (
    tester,
  ) async {
    final service = _FakeAudioDeviceCheckService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioDeviceCheck(
            inputDeviceId: 'input-1',
            inputDeviceLabel: 'USB microphone',
            outputDeviceId: 'output-1',
            outputDeviceLabel: 'USB speakers',
            serviceFactory: () => service,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Проверить микрофон'));
    await tester.pumpAndSettle();
    expect(service.startedInputId, 'input-1');
    expect(service.startedInputLabel, 'USB microphone');
    expect(
      find.textContaining('индикатор показывает локальный уровень'),
      findsOneWidget,
    );

    service.levels.add(0.42);
    await tester.pump();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.42,
    );

    await tester.tap(find.text('Остановить проверку микрофона'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Проверка микрофона выключена.'), findsOneWidget);
    expect(service.stopCount, 1);

    await tester.tap(find.text('Проверить динамик'));
    await tester.pumpAndSettle();
    expect(service.playedOutputId, 'output-1');
    expect(service.playedOutputLabel, 'USB speakers');
    expect(find.textContaining('Сигнал завершён.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(service.disposeCount, 1);
  });

  testWidgets(
    'stops an active microphone check when its selected device changes',
    (tester) async {
      final service = _FakeAudioDeviceCheckService();
      Widget buildCheck(String inputId) => MaterialApp(
        home: Scaffold(
          body: AudioDeviceCheck(
            inputDeviceId: inputId,
            inputDeviceLabel: inputId,
            outputDeviceId: null,
            outputDeviceLabel: null,
            serviceFactory: () => service,
          ),
        ),
      );

      await tester.pumpWidget(buildCheck('input-1'));
      await tester.tap(find.text('Проверить микрофон'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildCheck('input-2'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Проверка микрофона выключена.'), findsOneWidget);
      expect(service.stopCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('reports when the microphone level stream ends unexpectedly', (
    tester,
  ) async {
    final service = _FakeAudioDeviceCheckService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioDeviceCheck(
            inputDeviceId: 'input-1',
            inputDeviceLabel: 'USB microphone',
            outputDeviceId: null,
            outputDeviceLabel: null,
            serviceFactory: () => service,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Проверить микрофон'));
    await tester.pumpAndSettle();
    await service.levels.close();
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Не удалось проверить микрофон. Проверьте разрешение и выбранное устройство.',
      ),
      findsOneWidget,
    );
    expect(find.text('Проверить микрофон'), findsOneWidget);
    expect(service.stopCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeAudioDeviceCheckService implements AudioDeviceCheckService {
  final StreamController<double> levels = StreamController<double>.broadcast(
    sync: true,
  );
  String? startedInputId;
  String? startedInputLabel;
  String? playedOutputId;
  String? playedOutputLabel;
  int stopCount = 0;
  int disposeCount = 0;

  @override
  Future<Stream<double>> startMicrophone({
    String? deviceId,
    String? deviceLabel,
  }) async {
    startedInputId = deviceId;
    startedInputLabel = deviceLabel;
    return levels.stream;
  }

  @override
  Future<void> stopMicrophone() async {
    stopCount++;
  }

  @override
  Future<void> playSpeaker({String? deviceId, String? deviceLabel}) async {
    playedOutputId = deviceId;
    playedOutputLabel = deviceLabel;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await levels.close();
  }
}
