import 'package:boohtacord_desktop/src/features/admin/media_metrics/panel.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_topology_fake_api.dart';

AdminScreenSample _sample(DateTime at) => AdminScreenSample(
  platform: 'android_native', direction: 'receiver', state: 'playing',
  sampledAtUtc: at, frameWidth: 640, frameHeight: 360, decodedFps: 24,
);

Future<void> _mount(WidgetTester tester, TopologyTestApi api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: AdminMediaMetricsPanel(api: api),
  )));
  await tester.pump();
}

void main() {
  testWidgets('background stops polling and resume refreshes immediately', (tester) async {
    final api = TopologyTestApi();
    addTearDown(tester.view.reset);
    await _mount(tester, api);
    expect(api.screenMetricsLoads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 6));
    expect(api.screenMetricsLoads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(api.screenMetricsLoads, 2);
  });

  testWidgets('sender reports mark receiver-only stages as unavailable', (tester) async {
    final api = TopologyTestApi()
      ..screenMetrics = [
        AdminScreenSample(
          platform: 'android_native', direction: 'sender', state: 'playing',
          sampledAtUtc: DateTime.now().toUtc(), encodedFps: 30,
        ),
      ];
    addTearDown(tester.view.reset);
    await _mount(tester, api);
    for (final stage in ['Приём', 'Декодирование', 'Показ']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('media-stage-$stage')),
          matching: find.text('Нет данных'),
        ),
        findsOneWidget,
      );
    }
  });
}
