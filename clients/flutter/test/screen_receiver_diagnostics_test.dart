import 'dart:async';

import 'package:boohtacord_desktop/src/services/screen_share_metrics.dart';

import 'package:boohtacord_desktop/src/screens/screen_receiver_diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_client/src/stats/stats.dart';
import 'package:livekit_client/src/track/remote/video.dart' as livekit_remote;

void main() {
  test('computes receiver rates from counters and elapsed time', () {
    const previous = ScreenReceiverSnapshot(
      timestampMs: 1000,
      bytesReceived: 100000,
      framesDecoded: 20,
      framesRendered: 20,
      framesDropped: 1,
      packetsLost: 2,
    );
    const current = ScreenReceiverSnapshot(
      timestampMs: 3000,
      bytesReceived: 1100000,
      framesDecoded: 140,
      framesDropped: 4,
      jitterSeconds: 0.012,
      packetsLost: 3,
      frameWidth: 1920,
      frameHeight: 1080,
      framesPerSecond: 30,
      framesRendered: 80,
    );

    final metrics = compareScreenReceiverStats(previous, current);

    expect(metrics.bitrateKbps, 4000);
    expect(metrics.decodedFps, 60);
    expect(metrics.droppedFrames, 3);
    expect(metrics.jitterMs, 12);
    expect(metrics.packetsLost, 3);
    expect(metrics.presentedFps, 30);
  });

  test('maps native inbound framesRendered into receiver stats', () async {
    final track = livekit_remote.RemoteVideoTrack(
      TrackSource.screenShareVideo,
      _EmptyMediaStream(),
      _EmptyMediaStreamTrack(),
      receiver: _StatsReceiver([
        rtc.StatsReport('inbound-1', 'inbound-rtp', 3000, {
          'framesDecoded': 90,
          'framesRendered': 84,
          'framesDropped': 3,
        }),
      ]),
    );

    final stats = await track.getReceiverStats();

    expect(stats?.framesDecoded, 90);
    expect(stats?.framesRendered, 84);
    expect(stats?.framesDropped, 3);
  });

  test('does not invent rates without a valid baseline', () {
    const current = ScreenReceiverSnapshot(
      timestampMs: 2000,
      framesDecoded: 120,
      framesDropped: 4,
      bytesReceived: 50000,
      jitterSeconds: double.nan,
      packetsLost: -1,
    );

    final metrics = compareScreenReceiverStats(null, current);

    expect(metrics.bitrateKbps, isNull);
    expect(metrics.decodedFps, isNull);
    expect(metrics.droppedFrames, isNull);
    expect(metrics.jitterMs, isNull);
    expect(metrics.packetsLost, isNull);
  });

  testWidgets('a pending old track stats request cannot block a new track', (
    tester,
  ) async {
    final oldStats = Completer<VideoReceiverStats?>();
    final currentStats = Completer<VideoReceiverStats?>();
    final oldTrack = _StatsTrack(() => oldStats.future);
    final currentTrack = _StatsTrack(() => currentStats.future);
    final diagnosticsKey = GlobalKey();

    Widget build(RemoteVideoTrack track) => MaterialApp(
      home: Scaffold(
        body: ScreenReceiverDiagnostics(
          key: diagnosticsKey,
          track: track,
          isLocal: false,
          hasAudio: false,
        ),
      ),
    );

    await tester.pumpWidget(build(oldTrack));
    expect(oldTrack.calls, 1);

    await tester.pumpWidget(build(currentTrack));
    expect(currentTrack.calls, 1);

    oldStats.complete(null);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(currentTrack.calls, 1);

    currentStats.complete(VideoReceiverStats('new', 1));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('normalizes native microsecond timestamps before receiver rates', (
    tester,
  ) async {
    final samples = [
      VideoReceiverStats('inbound', 5000000)
        ..bytesReceived = 50000
        ..framesDecoded = 20
        ..framesRendered = 10
        ..framesDropped = 1
        ..frameWidth = 576
        ..frameHeight = 1280
        ..framesPerSecond = 14,
      VideoReceiverStats('inbound', 7000000)
        ..bytesReceived = 1050000
        ..framesDecoded = 140
        ..framesRendered = 50
        ..framesDropped = 4
        ..frameWidth = 576
        ..frameHeight = 1280
        ..framesPerSecond = 14,
    ];
    var nextSample = 0;
    final track = _StatsTrack(() async => samples[nextSample++]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: track,
            isLocal: false,
            hasAudio: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();

    expect(find.text('60 FPS'), findsOneWidget);
    expect(find.text('4000 кбит/с'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports receiver rates computed from normalized timestamps', (
    tester,
  ) async {
    final reports = <Map<String, Object>>[];
    final samples = [
      VideoReceiverStats('inbound', 5000000)
        ..bytesReceived = 50000
        ..framesDecoded = 20
        ..framesRendered = 10
        ..framesDropped = 1
        ..packetsReceived = 100
        ..packetsLost = 2
        ..jitter = 0.012
        ..frameWidth = 576
        ..frameHeight = 1280
        ..framesPerSecond = 14,
      VideoReceiverStats('inbound', 7000000)
        ..bytesReceived = 1050000
        ..framesDecoded = 140
        ..framesRendered = 50
        ..framesDropped = 4
        ..packetsReceived = 200
        ..packetsLost = 4
        ..jitter = 0.012
        ..frameWidth = 576
        ..frameHeight = 1280
        ..framesPerSecond = 14,
      VideoReceiverStats('inbound', 9000000)
        ..bytesReceived = 2050000
        ..framesDecoded = 260
        ..framesRendered = 90
        ..framesDropped = 7
        ..packetsReceived = 300
        ..packetsLost = 6
        ..jitter = 0.012
        ..frameWidth = 576
        ..frameHeight = 1280
        ..framesPerSecond = 14,
    ];
    var nextSample = 0;
    final track = _StatsTrack(() async => samples[nextSample++]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: track,
            isLocal: false,
            hasAudio: false,
            selectedStreamId: 'remote-screen',
            onReport: (report) async => reports.add(report),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(reports, hasLength(1));
    expect(reports.single, containsPair('platform', 'android_native'));
    expect(reports.single, containsPair('direction', 'receiver'));
    expect(reports.single, containsPair('state', 'playing'));
    expect(reports.single, containsPair('frame_width', 576));
    expect(reports.single, containsPair('frame_height', 1280));
    expect(reports.single, containsPair('decoded_fps', 60.0));
    expect(reports.single, containsPair('presented_fps', 20.0));
    expect(reports.single, containsPair('bitrate_kbps', 4000.0));
    expect(reports.single, containsPair('jitter_ms', 12.0));
    expect(reports.single, containsPair('packets_lost', 6));
    expect(reports.single, containsPair('dropped_frames', 3));
    expect(reports.single, isNot(contains('packet_loss_percent')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports missing receiver stats and local no-audio preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: null,
            isLocal: true,
            hasAudio: false,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ожидание статистики отправителя'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Профиль при запуске')).style?.fontSize,
      12,
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Предпросмотр без звука'), findsOneWidget);
    expect(find.text('Нет данных от приёмника'), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Предпросмотр без звука'), findsNothing);

    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(500, 100));
    await tester.pumpAndSettle();
    expect(find.text('Предпросмотр без звука'), findsNothing);
  });

  testWidgets('shows the source profile transmitted in the track name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: null,
            isLocal: false,
            hasAudio: false,
            sourceTrackName: 'screenshare-1440p-60fps',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    expect(find.text('1440p · 60 FPS'), findsOneWidget);
  });

  testWidgets('reports selected receiver samples but never local preview', (
    tester,
  ) async {
    final reports = <Map<String, Object>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: null,
            isLocal: false,
            hasAudio: false,
            selectedStreamId: 'remote-screen',
            reportEnabled: true,
            onReport: (report) async => reports.add(report),
          ),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(reports, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(reports, [
      {
        'platform': 'android_native',
        'direction': 'receiver',
        'state': 'waiting_subscription',
      },
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: null,
            isLocal: true,
            hasAudio: false,
            reportEnabled: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(reports, hasLength(1));
  });

  testWidgets('shows sender measurements in local preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: null,
            isLocal: true,
            hasAudio: false,
            senderReport: const ScreenShareSenderReport(
              platform: 'desktop_native',
              state: 'playing',
              frameWidth: 2560,
              frameHeight: 1440,
              encodedFps: 58.5,
              bitrateKbps: 4200,
              roundTripTimeMs: 45,
            ),
            senderSampledAt: DateTime(2026, 9, 29, 12, 34, 56),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Измерено в 12:34:56'), findsOneWidget);
    expect(find.text('Отправляется'), findsOneWidget);
    expect(find.text('2560 × 1440'), findsOneWidget);
    expect(find.text('Кодируется'), findsOneWidget);
    expect(find.text('58.5 FPS'), findsOneWidget);
    expect(find.text('4200 кбит/с'), findsOneWidget);
    expect(find.text('45 мс'), findsOneWidget);
    expect(find.text('12:34:56'), findsOneWidget);
    expect(find.text('Сейчас у зрителя'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScreenReceiverDiagnostics(
            track: null,
            isLocal: true,
            hasAudio: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ожидание статистики отправителя'), findsOneWidget);
    expect(find.text('2560 × 1440'), findsNothing);
    expect(find.text('58.5 FPS'), findsNothing);
  });

  testWidgets('keeps the diagnostics popover within a compact viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ScreenReceiverDiagnostics(
              track: null,
              isLocal: false,
              hasAudio: false,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();

    expect(find.text('Нет данных от приёмника'), findsOneWidget);
    final panelRect = tester.getRect(
      find.byKey(const ValueKey('screen-receiver-diagnostics-popover')),
    );
    expect(panelRect.width, 288);
    expect(panelRect.left, greaterThanOrEqualTo(0));
    expect(panelRect.right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  });
}

class _StatsTrack extends RemoteVideoTrack {
  _StatsTrack(this.readStats)
    : super(
        TrackSource.screenShareVideo,
        _EmptyMediaStream(),
        _EmptyMediaStreamTrack(),
      );

  final Future<VideoReceiverStats?> Function() readStats;
  int calls = 0;

  @override
  Future<VideoReceiverStats?> getReceiverStats() {
    calls++;
    return readStats();
  }
}

class _EmptyMediaStream implements rtc.MediaStream {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyMediaStreamTrack implements rtc.MediaStreamTrack {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StatsReceiver implements rtc.RTCRtpReceiver {
  _StatsReceiver(this.reports);

  final List<rtc.StatsReport> reports;

  @override
  Future<List<rtc.StatsReport>> getStats() async => reports;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
