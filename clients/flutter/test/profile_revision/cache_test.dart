import 'package:boohtacord_desktop/src/features/profile/revision/cache.dart';
import 'package:boohtacord_desktop/src/features/profile/revision/avatar_url.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracks server revisions without adding fields to aggregate models', () {
    final cache = ProfileRevisionCache();
    const own = OwnProfile(
      accountId: 'u1',
      login: 'login',
      displayName: 'Name',
      role: 'MEMBER',
    );
    const member = GuildMember(
      id: 'u1',
      login: 'login',
      displayName: 'Name',
      role: 'MEMBER',
      presence: MemberPresence.online,
    );

    cache.recordOwn(own, 4);
    cache.recordMember(member, 7);

    expect(cache.ownRevision(own), 4);
    expect(cache.memberRevision(member), 7);
  });

  test('rejects invalid server revision values and never fabricates one', () {
    final cache = ProfileRevisionCache();
    const member = GuildMember(
      id: 'u1',
      login: 'login',
      displayName: 'Name',
      role: 'MEMBER',
      presence: MemberPresence.unknown,
    );

    expect(() => cache.recordMember(member, 0), throwsFormatException);
    expect(cache.memberRevision(member), isNull);
  });

  test('preserves newer member metadata over a stale response', () {
    final cache = ProfileRevisionCache();
    const newest = GuildMember(
      id: 'u1',
      login: 'login',
      displayName: 'Newest',
      role: 'MEMBER',
      presence: MemberPresence.online,
    );
    const stale = GuildMember(
      id: 'u1',
      login: 'login',
      displayName: 'Stale',
      role: 'MEMBER',
      presence: MemberPresence.offline,
    );
    cache.recordMember(newest, 10);
    cache.recordMember(stale, 8);

    expect(cache.memberRevision(stale), 8);
    expect(cache.preserveNewer(stale, newest).displayName, 'Newest');
  });

  test('realtime member hint accepts only an exact positive revision payload', () {
    expect(
      parseMemberProfileHint({'user_id': 'u1', 'revision': 8}),
      (userId: 'u1', revision: 8),
    );
    expect(parseMemberProfileHint({'user_id': 'u1', 'revision': 0}), isNull);
    expect(
      parseMemberProfileHint({'user_id': 'u1', 'revision': 8, 'name': 'x'}),
      isNull,
    );
    expect(parseMemberProfileHint({'user_id': '', 'revision': 8}), isNull);
  });

  test('adds server revision to the existing protected avatar route', () {
    final result = withAvatarRevision(
      {'avatar_url': '/api/v1/members/u1/avatar?size=small'},
      9,
    );

    final uri = Uri.parse(result['avatar_url'] as String);
    expect(uri.path, '/api/v1/members/u1/avatar');
    expect(uri.queryParameters, {'size': 'small', 'revision': '9'});
  });
}
