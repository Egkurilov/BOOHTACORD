import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_prejoin_header_subtitle/component.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../voice_roster_state/support.dart';
import 'support.dart';

void main() {
  const channel = GuildChannel(
    id: 'voice-1',
    name: 'Voice',
    kind: ChannelKind.voice,
    admissionClosed: false,
  );
  test('stale empty header never describes an authoritative empty room', () {
    final harness = RosterHarness();
    addTearDown(harness.owner.dispose);
    harness.owner
      ..phase = VoiceRosterPhase.stale
      ..voiceRosters = [
        VoiceRoomRoster(channelId: 'voice-1', participants: []),
      ];
    expect(
      workspaceVoicePrejoinHeaderSubtitle(PreviewState(harness.owner), channel),
      'Голосовой канал · состав устарел',
    );
  });
  test('expired session header requests a new authenticated session', () {
    final harness = RosterHarness();
    addTearDown(harness.owner.dispose);
    harness.owner.phase = VoiceRosterPhase.sessionExpired;
    expect(
      workspaceVoicePrejoinHeaderSubtitle(PreviewState(harness.owner), channel),
      'Голосовой канал · сессия завершена',
    );
  });
  test('fresh empty header remains distinct from initial loading', () {
    final harness = RosterHarness();
    addTearDown(harness.owner.dispose);
    final state = PreviewState(harness.owner);
    expect(
      workspaceVoicePrejoinHeaderSubtitle(state, channel),
      'Голосовой канал · проверяем состав',
    );
    harness.owner
      ..phase = VoiceRosterPhase.fresh
      ..voiceRosters = [
        VoiceRoomRoster(channelId: 'voice-1', participants: []),
      ];
    expect(
      workspaceVoicePrejoinHeaderSubtitle(state, channel),
      'Голосовой канал · пока пусто',
    );
  });
}
