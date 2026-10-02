import 'dart:convert';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RosterApi extends ApiClient {
  @override
  Future<List<VoiceRoomRoster>> voiceParticipants() async => const [];
}

void main() {
  testWidgets('workspace roster refresh CPU frame and rebuild sample', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(RosterApi())
      ..phase = AppPhase.ready
      ..user = const SessionUser(accountId: 'benchmark-account', role: 'MEMBER')
      ..topology = const ChannelTopology(revision: 1, categories: [])
      ..voiceRosters = const [];
    await tester.pumpWidget(BoohtacordApp(state: state));
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await state.refreshVoiceRosters();
      await tester.pump();
    }
    var notifications = 0;
    var rebuilds = 0;
    state.addListener(() => notifications++);
    debugOnRebuildDirtyWidget = (_, _) {
      rebuilds++;
    };
    final micros = <int>[];
    for (var i = 0; i < 100; i++) {
      await state.refreshVoiceRosters();
      final watch = Stopwatch()..start();
      await tester.pump();
      watch.stop();
      micros.add(watch.elapsedMicroseconds);
    }
    debugOnRebuildDirtyWidget = null;
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    micros.sort();
    expect(notifications, 100);
    expect(rebuilds, greaterThan(0));
    expect(tester.takeException(), isNull);
    // CPU pump wall time in the debug test renderer; not GPU or physical-device FPS.
    print(
      'STATE_BENCHMARK ${jsonEncode({'scenario': '100 completed roster refreshes; empty authenticated workspace; 1440x900', 'state_notifications': notifications, 'dirty_widget_rebuilds': rebuilds, 'pump_median_us': micros[50], 'pump_p95_us': micros[95], 'renderer': 'flutter_test debug CPU; no network, GPU, or media'})}',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
