String sessionHandle(dynamic value) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    throw ArgumentError('Некорректный идентификатор сеанса.');
  }
  return value;
}

class OwnSession {
  const OwnSession({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.lastActiveAt,
    required this.current,
  });
  final String id, label;
  final DateTime createdAt, lastActiveAt;
  final bool current;
  factory OwnSession.fromJson(Map<String, dynamic> json) => OwnSession(
    id: sessionHandle(json['id']),
    label: json['label'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    lastActiveAt: DateTime.parse(json['last_active_at'] as String),
    current: json['current'] as bool,
  );
}

class OwnSessionPage {
  const OwnSessionPage({
    required this.accountId,
    required this.sessions,
    this.nextCursor,
  });
  final String accountId;
  final List<OwnSession> sessions;
  final String? nextCursor;
  factory OwnSessionPage.fromJson(Map<String, dynamic> json) => OwnSessionPage(
    accountId: sessionHandle(json['account_id']),
    sessions: List.unmodifiable(
      (json['sessions'] as List).map(
        (row) => OwnSession.fromJson(row as Map<String, dynamic>),
      ),
    ),
    nextCursor: json['next_cursor'] == null
        ? null
        : sessionHandle(json['next_cursor']),
  );
}
