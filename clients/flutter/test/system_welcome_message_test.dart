import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/models.dart';

void main() {
  final row = {
    'id': 'message',
    'channel_id': 'channel',
    'author_id': 'member',
    'body': 'врывается в гильдию.',
    'created_at': '2026-10-05T00:00:00Z',
    'revision': 1,
    'kind': 'SYSTEM_WELCOME',
    'mention_user_ids': ['member'],
    'attachments': [],
  };
  test('system kind survives history and deleted copies', () {
    final message = ChatMessage.fromJson(row);
    expect(message.kind, 'SYSTEM_WELCOME');
    expect(message.asDeleted().kind, 'SYSTEM_WELCOME');
    expect(
      message.withSendStatus(MessageSendStatus.failed).kind,
      'SYSTEM_WELCOME',
    );
  });
  test('unknown message kinds rejected', () {
    expect(
      () => ChatMessage.fromJson({...row, 'kind': 'FAKE'}),
      throwsFormatException,
    );
  });
}
