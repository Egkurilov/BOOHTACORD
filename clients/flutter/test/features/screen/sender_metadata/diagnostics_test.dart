import 'dart:convert';

import 'package:boohtacord_desktop/src/screens/screen_receiver_diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('labels mode and requested profile as sender metadata', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_descriptor()));
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();

    expect(find.text('Режим отправителя'), findsOneWidget);
    expect(find.text('Плавность'), findsOneWidget);
    expect(find.text('Выбрано отправителем'), findsOneWidget);
    expect(find.text('1080p · 60 FPS'), findsOneWidget);
    expect(find.text('Сейчас у зрителя'), findsOneWidget);
    expect(find.text('Нет данных'), findsOneWidget);
  });

  testWidgets('keeps legacy track diagnostics and omits invented sender data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(null, trackName: 'screenshare-720p-15fps'),
    );
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();

    expect(find.text('Профиль при запуске'), findsOneWidget);
    expect(find.text('720p · 15 FPS'), findsOneWidget);
    expect(find.text('Режим отправителя'), findsOneWidget);
    expect(find.text('Нет данных от отправителя'), findsNWidgets(2));
  });

  testWidgets('ignores an out-of-order descriptor revision', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_app(_descriptor(revision: 8), key: key));
    await tester.pumpWidget(_app(_descriptor(revision: 7), key: key));
    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();

    expect(find.text('Выбрано отправителем'), findsOneWidget);
    expect(find.text('1080p · 60 FPS'), findsOneWidget);
  });
}

Widget _app(String? descriptor, {String? trackName, Key? key}) => MaterialApp(
  home: Scaffold(
    body: ScreenReceiverDiagnostics(
      key: key,
      track: null,
      isLocal: false,
      hasAudio: false,
      senderDescriptorJson: descriptor,
      expectedSenderAccountId: 'account-a',
      expectedRoomId: 'room-a',
      sourceTrackName: trackName,
    ),
  ),
);

String _descriptor({int revision = 8}) => jsonEncode({
  'schema_version': 1,
  'scope': {
    'origin_id': 'origin-a',
    'account_id': 'account-a',
    'room_id': 'room-a',
    'media_session_id': 'session-a',
    'publication_generation': 4,
    'operation_revision': revision,
  },
  'mode': 'motion',
  'publisher_state': 'sharing',
  'viewer_state': 'idle',
  'requested_profile_id': 'P1080_60',
  'effective_profile': {
    'capture': {'max_width': 1920, 'max_height': 1080, 'max_fps': 60},
    'encoding': {
      'codec': null,
      'layers': [
        {
          'rid': null,
          'width': 1920,
          'height': 1080,
          'max_fps': 60,
          'max_bitrate_bps': 8000000,
          'scale_down_by': 1,
          'active': true,
        },
      ],
    },
  },
  'layer_topology': 'single-layer',
  'profile_revision': 1,
  'capabilities': {
    'live_update': true,
    'republish_without_recapture': false,
    'simulcast': false,
  },
  'reason_codes': ['user-request'],
});
