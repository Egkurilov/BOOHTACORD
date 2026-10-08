const reactionEmojis = ['👍', '❤️', '😂', '🎉', '👀', '✅'];
bool socialUuid(Object? value) =>
    value is String &&
    RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);

class MessageReaction {
  const MessageReaction(this.messageId, this.emoji, this.count, this.mine);
  final String messageId, emoji;
  final int count;
  final bool mine;
}

class ReactionPage {
  const ReactionPage(this.rows, this.canPin);
  final List<MessageReaction> rows;
  final bool canPin;
  factory ReactionPage.parse(dynamic value, bool direct, Set<String> wanted) {
    if (value is! Map ||
        value['reactions'] is! List ||
        value['can_pin'] is! bool ||
        (value['reactions'] as List).length > 600 ||
        direct && value['can_pin'] == true) {
      throw const FormatException('Некорректные реакции.');
    }
    final seen = <String>{}, rows = <MessageReaction>[];
    for (final row in value['reactions'] as List) {
      if (row is! Map ||
          !socialUuid(row['message_id']) ||
          !wanted.contains(row['message_id']) ||
          !reactionEmojis.contains(row['emoji']) ||
          row['count'] is! int ||
          row['count'] < 1 ||
          row['mine'] is! bool ||
          !seen.add('${row['message_id']}:${row['emoji']}')) {
        throw const FormatException('Некорректная реакция.');
      }
      rows.add(
        MessageReaction(
          row['message_id'] as String,
          row['emoji'] as String,
          row['count'] as int,
          row['mine'] as bool,
        ),
      );
    }
    return ReactionPage(List.unmodifiable(rows), value['can_pin'] as bool);
  }
}
