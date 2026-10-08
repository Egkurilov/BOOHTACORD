import 'package:boohtacord_desktop/src/features/audio/devices/state.dart';
import 'package:boohtacord_desktop/src/features/audio/settings/scan_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> showNotice(
    WidgetTester tester, {
    required AudioDeviceScanStatus status,
    AudioDeviceScanFailure? failure,
    int inputs = 0,
    int outputs = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioDeviceScanNotice(
            status: status,
            failure: failure,
            inputCount: inputs,
            outputCount: outputs,
          ),
        ),
      ),
    );
  }

  testWidgets('initializing inventory is visibly pending', (tester) async {
    await showNotice(tester, status: AudioDeviceScanStatus.initializing);

    expect(find.text('Проверяем доступ и запускаем аудиосистему…'), findsOneWidget);
    expect(find.text('Список устройств пока не готов.'), findsOneWidget);
  });

  testWidgets('permission denial gives macOS recovery instructions', (
    tester,
  ) async {
    await showNotice(
      tester,
      status: AudioDeviceScanStatus.error,
      failure: AudioDeviceScanFailure.permissionDenied,
    );

    expect(find.text('macOS запретил доступ к микрофону.'), findsOneWidget);
    expect(find.textContaining('Конфиденциальность и безопасность → Микрофон'), findsOneWidget);
  });

  testWidgets('restricted permission explains that system policy must change', (
    tester,
  ) async {
    await showNotice(
      tester,
      status: AudioDeviceScanStatus.error,
      failure: AudioDeviceScanFailure.permissionRestricted,
    );

    expect(find.text('Доступ к микрофону ограничен системой.'), findsOneWidget);
    expect(find.textContaining('не запрашивает разрешение автоматически'), findsOneWidget);
  });

  testWidgets('native initialization failure is distinct from denial', (
    tester,
  ) async {
    await showNotice(
      tester,
      status: AudioDeviceScanStatus.error,
      failure: AudioDeviceScanFailure.initializationFailed,
    );

    expect(find.textContaining('аудиосистему'), findsOneWidget);
    expect(find.textContaining('Конфиденциальность и безопасность'), findsNothing);
  });

  testWidgets('ready empty inventory is an informational state', (tester) async {
    await showNotice(tester, status: AudioDeviceScanStatus.ready);

    expect(find.text('Аудиоустройства не найдены.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('one real endpoint is reported as a successful inventory', (
    tester,
  ) async {
    await showNotice(
      tester,
      status: AudioDeviceScanStatus.ready,
      inputs: 1,
    );

    expect(find.text('Список аудиоустройств обновлён.'), findsOneWidget);
    expect(find.textContaining('микрофонов: 1'), findsOneWidget);
  });
}
