import '../../../models.dart';

class ProfileRevisionCache {
  final _own = Expando<int>('own-profile-revision');
  final _members = Expando<int>('member-profile-revision');

  int? ownRevision(OwnProfile value) => _own[value];
  int? memberRevision(GuildMember value) => _members[value];

  void recordOwn(OwnProfile value, int revision) {
    _own[value] = _positive(revision);
  }

  void recordMember(GuildMember value, int revision) {
    final parsed = _positive(revision);
    _members[value] = parsed;
  }

  GuildMember preserveNewer(GuildMember incoming, GuildMember current) {
    final oldRevision = memberRevision(current);
    final newRevision = memberRevision(incoming);
    if (oldRevision == null ||
        (newRevision != null && newRevision >= oldRevision)) {
      return incoming;
    }
    final result = GuildMember(
      id: incoming.id,
      login: incoming.login,
      displayName: current.displayName,
      role: incoming.role,
      presence: incoming.presence,
      avatarUrl: current.avatarUrl,
    );
    recordMember(result, oldRevision);
    return result;
  }

  GuildMember withLatestProfile(GuildMember incoming, GuildMember current) {
    final revision = memberRevision(incoming);
    final result = GuildMember(
      id: incoming.id,
      login: incoming.login,
      displayName: incoming.displayName,
      role: incoming.role,
      presence: current.presence,
      avatarUrl: incoming.avatarUrl,
    );
    if (revision != null) recordMember(result, revision);
    return result;
  }

  static int _positive(int value) {
    if (value <= 0) throw const FormatException('Invalid profile revision.');
    return value;
  }
}

final memberProfileRevisions = ProfileRevisionCache();

({String userId, int revision})? parseMemberProfileHint(Object? value) {
  if (value is! Map<String, dynamic> || value.length != 2) return null;
  final userId = value['user_id'];
  final revision = value['revision'];
  if (userId is! String ||
      userId.isEmpty ||
      revision is! int ||
      revision <= 0) {
    return null;
  }
  return (userId: userId, revision: revision);
}
