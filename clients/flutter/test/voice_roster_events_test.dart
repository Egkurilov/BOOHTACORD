import 'package:boohtacord_desktop/src/services/voice_roster_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a pushed roster snapshot including microphone state', () {
    final rooms = parseVoiceRosterEvent(
      'data: {"channels":[{"channel_id":"voice-1","participants":[{"account_id":"user-1","display_name":"Мика","screen_sharing":true,"microphone_muted":true}]}]}',
    );
    expect(rooms, hasLength(1));
    expect(rooms!.single.participants.single.microphoneMuted, isTrue);
  });

  test('ignores SSE comments and rejects duplicate channels', () {
    expect(parseVoiceRosterEvent(': heartbeat'), isNull);
    expect(
      () => parseVoiceRosterEvent(
        'data: {"channels":[{"channel_id":"x","participants":[]},{"channel_id":"x","participants":[]}]}',
      ),
      throwsFormatException,
    );
  });
}
