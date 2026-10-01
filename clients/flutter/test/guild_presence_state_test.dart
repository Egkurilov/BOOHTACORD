import 'package:boohtacord_desktop/src/guild_presence_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const onlineId = '11111111-1111-4111-8111-111111111111';
  const offlineId = '22222222-2222-4222-8222-222222222222';

  test('snapshot and changes resolve presence with REST fallback', () {
    final presence = GuildPresenceState();
    expect(
      presence.resolve(onlineId, MemberPresence.unknown),
      MemberPresence.unknown,
    );

    expect(presence.acceptSnapshot([onlineId]), isTrue);
    expect(
      presence.resolve(onlineId, MemberPresence.offline),
      MemberPresence.online,
    );
    expect(
      presence.resolve(offlineId, MemberPresence.unknown),
      MemberPresence.offline,
    );

    expect(presence.acceptChange(onlineId, 'offline'), isTrue);
    expect(
      presence.resolve(onlineId, MemberPresence.online),
      MemberPresence.offline,
    );
  });

  test('unavailable feed shows unknown until the next full snapshot', () {
    final presence = GuildPresenceState();
    presence.acceptSnapshot([onlineId]);
    presence.acceptChange(offlineId, 'online');
    presence.invalidate();

    expect(presence.unavailable, isTrue);
    expect(
      presence.resolve(onlineId, MemberPresence.online),
      MemberPresence.unknown,
    );
    expect(
      presence.resolve(offlineId, MemberPresence.offline),
      MemberPresence.unknown,
    );

    presence.acceptChange(offlineId, 'online');
    expect(
      presence.resolve(offlineId, MemberPresence.offline),
      MemberPresence.unknown,
    );

    expect(presence.acceptSnapshot([offlineId]), isTrue);
    expect(presence.unavailable, isFalse);
    expect(
      presence.resolve(offlineId, MemberPresence.offline),
      MemberPresence.online,
    );
    expect(
      presence.resolve(onlineId, MemberPresence.online),
      MemberPresence.offline,
    );
  });

  test('malformed payload invalidates rather than trusting partial data', () {
    final presence = GuildPresenceState();
    presence.acceptSnapshot([onlineId]);

    expect(presence.acceptSnapshot([onlineId, 42]), isFalse);
    expect(
      presence.resolve(onlineId, MemberPresence.online),
      MemberPresence.unknown,
    );
    expect(presence.acceptChange('not-an-id', 'online'), isFalse);
    expect(presence.unavailable, isTrue);
  });
}
