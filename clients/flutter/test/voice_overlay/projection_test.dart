import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/projection.dart';

void main() {
  const members = <VoiceOverlayMemberInput>[
    VoiceOverlayMemberInput(
      displayName: 'Alice',
      speaking: true,
      microphoneMuted: false,
    ),
    VoiceOverlayMemberInput(
      displayName: 'Bob',
      speaking: false,
      microphoneMuted: true,
    ),
    VoiceOverlayMemberInput(
      displayName: 'Carol',
      speaking: true,
      microphoneMuted: false,
    ),
  ];

  test('renders only the active channel and caps the compact roster', () {
    final state = projectVoiceOverlay(
      settings: const VoiceOverlaySettings(enabled: true, onlySpeakers: false),
      voiceChannelId: 'voice-a',
      rosterChannelId: 'voice-a',
      voiceStatus: VoiceOverlayVoiceStatus.connected,
      members: members,
      maxParticipants: 2,
    );

    expect(state.visible, isTrue);
    expect(state.members, hasLength(2));
    expect(state.members.map((member) => member.displayName), ['Alice', 'Bob']);
  });

  test('only-speakers mode preserves simultaneous speakers', () {
    final state = projectVoiceOverlay(
      settings: const VoiceOverlaySettings(enabled: true, onlySpeakers: true),
      voiceChannelId: 'voice-a',
      rosterChannelId: 'voice-a',
      voiceStatus: VoiceOverlayVoiceStatus.connected,
      members: members,
    );

    expect(
      state.members.map((member) => member.displayName),
      ['Alice', 'Carol'],
    );
  });

  test('reconnect clears speaking flags while retaining channel members', () {
    final state = projectVoiceOverlay(
      settings: const VoiceOverlaySettings(enabled: true, onlySpeakers: false),
      voiceChannelId: 'voice-a',
      rosterChannelId: 'voice-a',
      voiceStatus: VoiceOverlayVoiceStatus.reconnecting,
      members: members,
    );

    expect(state.members, hasLength(3));
    expect(state.members.every((member) => !member.speaking), isTrue);
  });

}
