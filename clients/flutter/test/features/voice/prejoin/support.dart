import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/features/voice/prejoin/roster_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../voice_roster_state/support.dart';

class PreviewState implements AppState {
  PreviewState(this.voiceRoster);
  @override
  final VoiceRosterController voiceRoster;
  @override
  List<VoiceRoomRoster>? get voiceRosters => voiceRoster.voiceRosters;
  @override
  String? get voiceRosterError => voiceRoster.voiceRosterError;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> showPreview(WidgetTester tester, RosterHarness harness) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceRosterPreview(
            state: PreviewState(harness.owner),
            channelId: 'voice-1',
          ),
        ),
      ),
    );
