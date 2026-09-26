import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/message_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the reply boundary used by message grouping', () {
    final message = ChatMessage.fromJson({
      'id': 'message-2',
      'channel_id': 'channel',
      'author_id': 'author',
      'body': 'Ответ',
      'created_at': '2026-09-25T10:01:00Z',
      'revision': 1,
      'reply_to_id': 'message-1',
      'mention_user_ids': ['account-mentioned'],
    });

    expect(message.replyToId, 'message-1');
    expect(message.mentionUserIds, ['account-mentioned']);
  });

  test('groups same-author messages for at most five minutes', () {
    final start = DateTime(2026, 9, 25, 10);
    final messages = [
      _message('1', start),
      _message('2', start.add(const Duration(minutes: 5))),
      _message('3', start.add(const Duration(minutes: 10, seconds: 1))),
      _message('4', start.add(const Duration(minutes: 11)), authorId: 'other'),
      _message('5', start.add(const Duration(minutes: 12)), replyToId: 'reply'),
      _message('6', start.add(const Duration(minutes: 13))),
      _message('7', start.add(const Duration(minutes: 14)), deleted: true),
      _message('8', start.add(const Duration(minutes: 15))),
      _message('9', DateTime(2026, 9, 26, 9)),
    ];

    expect(presentMessages(messages).map((entry) => entry.grouped), [
      false,
      true,
      false,
      false,
      false,
      false,
      false,
      false,
      false,
    ]);
  });

  test('adds one localized date divider at each local calendar-day change', () {
    final timeline = messageTimeline([
      _message('1', DateTime(2026, 9, 25, 10)),
      _message('2', DateTime(2026, 9, 25, 10, 1)),
      _message('3', DateTime(2026, 9, 26, 9)),
    ]);

    expect(
      timeline
          .where((entry) => entry.message == null)
          .map((entry) => entry.dateLabel),
      ['25 сентября 2026', '26 сентября 2026'],
    );
    expect(timeline.where((entry) => entry.message != null), hasLength(3));
  });
}

ChatMessage _message(
  String id,
  DateTime createdAt, {
  String authorId = 'author',
  String? replyToId,
  bool deleted = false,
}) => ChatMessage(
  id: id,
  channelId: 'channel',
  authorId: authorId,
  body: id,
  createdAt: createdAt,
  deleted: deleted,
  revision: 1,
  replyToId: replyToId,
);
