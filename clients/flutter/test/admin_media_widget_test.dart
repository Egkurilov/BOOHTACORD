import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

Future<AppState> _openMedia(WidgetTester tester, TopologyTestApi api) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  final state = AppState(api)..topology = api.current;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AdminScreen(state: state)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('admin-section-tab-media')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('admin-section-tab-media')));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('media tab renders anonymous receiver metrics responsively', (
    tester,
  ) async {
    final api = TopologyTestApi()
      ..screenMetrics = [
        AdminScreenSample(
          platform: 'android_native',
          direction: 'receiver',
          state: 'playing',
          sampledAtUtc: DateTime.now().toUtc(),
          frameWidth: 540,
          frameHeight: 1170,
          decodedFps: 14.5,
          presentedFps: 12,
          bitrateKbps: 109.5,
          jitterMs: 4,
          packetsLost: 2,
          droppedFrames: 1,
          rttMs: 36,
        ),
      ];
    final state = await _openMedia(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    expect(find.text('Android · приложение · приём'), findsOneWidget);
    expect(find.textContaining('Размер кадра · 540 × 1170'), findsOneWidget);
    expect(find.textContaining('Декодировано · 14.5 FPS'), findsOneWidget);
    await tester.tap(find.text('Дополнительные измерения'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Битрейт · 109.5 кбит/с'), findsOneWidget);
    expect(find.textContaining('RTT · 36 мс'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('media loading failures are announced and can be retried', (
    tester,
  ) async {
    final api = TopologyTestApi()
      ..screenMetricsFailure = Exception('private server detail');
    final state = await _openMedia(tester, api);
    addTearDown(() {
      tester.view.reset();
      state.dispose();
    });

    expect(find.text('Не удалось загрузить показатели.'), findsOneWidget);
    expect(find.textContaining('private server detail'), findsNothing);
    api.screenMetricsFailure = null;
    await tester.tap(find.widgetWithText(TextButton, 'Обновить'));
    await tester.pumpAndSettle();

    expect(api.screenMetricsLoads, 2);
    expect(
      find.text(
        'Свежих показателей пока нет. Откройте демонстрацию у зрителя.',
      ),
      findsOneWidget,
    );
  });
}
