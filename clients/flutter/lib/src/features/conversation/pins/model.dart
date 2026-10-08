import '../reactions/model.dart';

class TextPin {
  const TextPin(
    this.messageId,
    this.authorId,
    this.preview,
    this.createdAt,
    this.pinnedAt,
  );
  final String messageId, authorId, preview;
  final DateTime createdAt, pinnedAt;
}

class TextPinPage {
  const TextPinPage(this.pins, this.canManage, this.nextCursor);
  final List<TextPin> pins;
  final bool canManage;
  final String? nextCursor;
  factory TextPinPage.parse(dynamic value) {
    if (value is! Map ||
        value['pins'] is! List ||
        (value['pins'] as List).length > 50 ||
        value['can_manage'] is! bool) {
      throw const FormatException('Некорректные закрепления.');
    }
    final cursor = value['next_cursor'];
    if (cursor != null &&
        (cursor is! String || cursor.isEmpty || cursor.length > 256)) {
      throw const FormatException('Некорректный курсор.');
    }
    final pins = <TextPin>[], seen = <String>{};
    for (final row in value['pins'] as List) {
      if (row is! Map ||
          !socialUuid(row['message_id']) ||
          !seen.add(row['message_id'] as String) ||
          !socialUuid(row['author_id']) ||
          row['preview'] is! String ||
          (row['preview'] as String).runes.length > 240 ||
          row['pinned_at'] is! String ||
          row['message_created_at'] is! String) {
        throw const FormatException('Некорректное закрепление.');
      }
      pins.add(
        TextPin(
          row['message_id'] as String,
          row['author_id'] as String,
          row['preview'] as String,
          DateTime.parse(row['message_created_at'] as String),
          DateTime.parse(row['pinned_at'] as String),
        ),
      );
    }
    return TextPinPage(
      List.unmodifiable(pins),
      value['can_manage'] as bool,
      cursor as String?,
    );
  }
}
