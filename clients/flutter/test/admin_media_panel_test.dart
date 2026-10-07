import 'package:boohtacord_desktop/src/features/admin/media_metrics/panel.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

AdminScreenSample _sample(DateTime at, {String direction = 'receiver'}) => AdminScreenSample(
  platform: 'android_native', direction: direction, state: 'playing',
  sampledAtUtc: at,
  frameWidth: direction == 'receiver' ? 640 : null,
  frameHeight: direction == 'receiver' ? 360 : null,
  encodedFps: direction == 'sender' ? 30 : null,
  decodedFps: direction == 'receiver' ? 24 : null,
  presentedFps: direction == 'receiver' ? 23 : null,
  bitrateKbps: 100, rttMs: 30,
);

Future<void> _mount(WidgetTester tester, TopologyTestApi api,
    {DateTime Function()? clock}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: AdminMediaMetricsPanel(api: api, clock: clock),
  )));
  await tester.pump();
}

void main() {
  testWidgets('freshness expires on elapsed time without another request', (tester) async {
    var now = DateTime.utc(2026, 10, 7, 12);
    final api = TopologyTestApi()
      ..screenMetrics = [_sample(now.subtract(const Duration(seconds: 59)))];
    addTearDown(tester.view.reset);
    await _mount(tester, api, clock: () => now);
    expect(api.screenMetricsLoads, 1);
    expect(find.textContaining('Состояние: Свежие данные'), findsOneWidget);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(api.screenMetricsLoads, 1);
    expect(find.textContaining('Состояние: Устарело'), findsOneWidget);
  });

  testWidgets('refresh errors hide old samples and retry recovers', (tester) async {
    final now = DateTime.now().toUtc();
    final api = TopologyTestApi()..screenMetrics = [_sample(now)];
    addTearDown(tester.view.reset);
    await _mount(tester, api);
    expect(find.byKey(const ValueKey('admin-media-sample')), findsOneWidget);
    api.screenMetricsFailure = Exception('private response detail');
    await tester.tap(find.widgetWithText(TextButton, 'Обновить'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Не удалось загрузить показатели.'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-media-sample')), findsNothing);
    expect(find.textContaining('private response detail'), findsNothing);
    api.screenMetricsFailure = null;
    await tester.tap(find.widgetWithText(TextButton, 'Обновить'));
    await tester.pump();
    await tester.pump();
    expect(api.screenMetricsLoads, 3);
    expect(find.byKey(const ValueKey('admin-media-sample')), findsOneWidget);
  });

  testWidgets('pipeline adapts to narrow and wide widths without overflow', (tester) async {
    final api = TopologyTestApi()
      ..screenMetrics = [_sample(DateTime.now().toUtc())];
    addTearDown(tester.view.reset);
    await _mount(tester, api);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('media-stage-Отправка')),
        matching: find.text('Нет данных'),
      ),
      findsOneWidget,
    );
    for (final width in [360.0, 600.0, 768.0, 840.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pump();
      final tops = [
        for (final name in ['Отправка', 'Приём', 'Декодирование', 'Показ'])
          tester.getTopLeft(find.byKey(ValueKey('media-stage-$name'))).dy,
      ].toSet();
      expect(tops.length, width < 420 ? 4 : width < 840 ? 2 : 1);
      expect(tester.takeException(), isNull);
    }
  });


}
