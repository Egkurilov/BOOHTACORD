import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps a channel description from topology responses', () {
    final channel = GuildChannel.fromJson({
      'id': 'text-1',
      'name': 'Общее',
      'description': 'Общение на любые темы',
      'kind': 'TEXT',
      'admission_closed': false,
      'unread_count': 2,
      'mention_count': 1,
    });

    expect(channel.description, 'Общение на любые темы');
    expect(
      channel.withUnreadCounts(unread: 4, mentions: 3).description,
      channel.description,
    );
  });

  test('rejects malformed or oversized channel descriptions', () {
    final base = <String, dynamic>{
      'id': 'text-1',
      'name': 'Общее',
      'kind': 'TEXT',
      'admission_closed': false,
      'unread_count': 0,
      'mention_count': 0,
    };

    expect(
      () => GuildChannel.fromJson({...base, 'description': 42}),
      throwsFormatException,
    );
    expect(
      () => GuildChannel.fromJson({...base, 'description': '😀' * 201}),
      throwsFormatException,
    );
  });
}
