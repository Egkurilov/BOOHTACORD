import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/projection.dart';

void main() {
  const settings = VoiceOverlaySettings(enabled: true, onlySpeakers: false);
  const members = [
    VoiceOverlayMemberInput(
      displayName: 'Alice',
      speaking: true,
      microphoneMuted: false,
    ),
  ];

  test('channel change and disabled settings clear participant details', () {
    final channelChanged = projectVoiceOverlay(
      settings: settings,
      voiceChannelId: 'voice-b',
      rosterChannelId: 'voice-a',
      voiceStatus: VoiceOverlayVoiceStatus.connected,
      members: members,
    );
    final disabled = projectVoiceOverlay(
      settings: const VoiceOverlaySettings(enabled: false, onlySpeakers: false),
      voiceChannelId: 'voice-a',
      rosterChannelId: 'voice-a',
      voiceStatus: VoiceOverlayVoiceStatus.connected,
      members: members,
    );

    expect(channelChanged.visible, isFalse);
    expect(channelChanged.members, isEmpty);
    expect(disabled.visible, isFalse);
    expect(disabled.members, isEmpty);
  });

  test('disconnect does not retain names or stale speaker indicators', () {
    final state = projectVoiceOverlay(
      settings: settings,
      voiceChannelId: null,
      rosterChannelId: 'voice-a',
      voiceStatus: VoiceOverlayVoiceStatus.disconnected,
      members: members,
    );

    expect(state.visible, isFalse);
    expect(state.members, isEmpty);
  });
}
