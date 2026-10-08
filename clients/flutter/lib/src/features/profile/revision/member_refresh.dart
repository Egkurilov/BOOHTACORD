import '../../../models.dart';

class MemberProfileRefreshes {
  final _pending = <_MemberRefreshKey, _PendingMemberRefresh>{};

  Future<GuildMember> refresh(
    Object sessionScope,
    String userId,
    int minimumRevision,
    Future<GuildMember> Function() read,
    int? Function(GuildMember) revisionOf,
  ) {
    final key = _MemberRefreshKey(sessionScope, userId);
    final active = _pending[key];
    if (active != null) {
      if (minimumRevision > active.minimumRevision) {
        active.minimumRevision = minimumRevision;
      }
      return active.result;
    }
    final pending = _PendingMemberRefresh(minimumRevision);
    _pending[key] = pending;
    pending.result = _readLatest(pending, read, revisionOf).whenComplete(() {
      if (identical(_pending[key], pending)) _pending.remove(key);
    });
    return pending.result;
  }

  Future<GuildMember> _readLatest(
    _PendingMemberRefresh pending,
    Future<GuildMember> Function() read,
    int? Function(GuildMember) revisionOf,
  ) async {
    late GuildMember result;
    for (var attempt = 0; attempt < 2; attempt++) {
      final requested = pending.minimumRevision;
      result = await read();
      if ((revisionOf(result) ?? 0) >= pending.minimumRevision ||
          pending.minimumRevision == requested) {
        return result;
      }
    }
    return result;
  }
}

class _MemberRefreshKey {
  const _MemberRefreshKey(this.sessionScope, this.userId);
  final Object sessionScope;
  final String userId;

  @override
  bool operator ==(Object other) => other is _MemberRefreshKey &&
      identical(sessionScope, other.sessionScope) && userId == other.userId;

  @override
  int get hashCode => Object.hash(identityHashCode(sessionScope), userId);
}

class _PendingMemberRefresh {
  _PendingMemberRefresh(this.minimumRevision);
  int minimumRevision;
  late Future<GuildMember> result;
}

final memberProfileRefreshes = MemberProfileRefreshes();
