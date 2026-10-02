import 'dart:convert';

import 'package:boohtacord_desktop/src/screens/screen_receiver_diagnostics.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/screen_receiver_report.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie': 'session=test-session',
    });
  });

  test(
    'posts normalized receiver measurements to the screen metrics API',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response('', 204);
        }),
      );
      final report = buildScreenReceiverReport(
        platform: 'android_native',
        selected: true,
        hasTrack: true,
        current: const ScreenReceiverSnapshot(
          timestampMs: 9000,
          bytesReceived: 2050000,
          framesDecoded: 260,
          framesRendered: 90,
          framesDropped: 7,
          jitterSeconds: 0.012,
          packetsLost: 6,
          frameWidth: 576,
          frameHeight: 1280,
          framesPerSecond: 0,
        ),
        metrics: const ScreenReceiverMetrics(
          bitrateKbps: 4000,
          decodedFps: 60,
          presentedFps: 20,
          droppedFrames: 3,
          jitterMs: 12,
          packetsLost: 6,
          packetLossPercent: 2,
        ),
        sampleAgeMs: 1000,
        packetLossWindowMs: 10000,
      );
      expect(report, isNotNull);

      await api.reportScreenShareMetrics(report!);

      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/voice/screen-metrics');
      expect(request.headers['origin'], 'https://v.bootybay.ru');
      expect(request.headers['cookie'], 'session=test-session');
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), report);
      expect(request.body, isNot(contains('account_id')));
      expect(request.body, isNot(contains('channel_id')));
      expect(request.body, isNot(contains('track_id')));
    },
  );
}
