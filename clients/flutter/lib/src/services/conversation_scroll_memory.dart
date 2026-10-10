class ConversationScrollPosition {
  const ConversationScrollPosition({
    required this.offset,
    required this.followLatest,
  });

  final double offset;
  final bool followLatest;
}

/// Keeps only local text-history position while the authenticated workspace
/// rebuilds its responsive shell. Message contents are never cached here.
abstract final class ConversationScrollMemory {
  static final Map<String, ConversationScrollPosition> _positions = {};
  static int _epoch = 0;

  static int get epoch => _epoch;

  static String _key(String accountId, String channelId) =>
      '$accountId\u0000$channelId';

  static ConversationScrollPosition? load(String accountId, String channelId) =>
      _positions[_key(accountId, channelId)];

  static void save({
    required String accountId,
    required String channelId,
    required double offset,
    required bool followLatest,
    required int epoch,
  }) {
    if (epoch != _epoch || !offset.isFinite || offset < 0) return;
    _positions[_key(accountId, channelId)] = ConversationScrollPosition(
      offset: offset,
      followLatest: followLatest,
    );
  }

  static void clear() {
    _epoch++;
    _positions.clear();
  }
}
