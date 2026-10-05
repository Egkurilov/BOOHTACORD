import '../../text/message_model/kind.dart';

enum SearchMessageKind { channel, directMessage }

bool _isUuid(Object? value) =>
    value is String &&
    RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);

class SearchMessage {
  const SearchMessage({
    required this.id,
    required this.kind,
    required this.conversationId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.revision,
    this.editedAt,
    this.messageKind = 'USER',
  });
  final String messageKind;
  final String id;
  final SearchMessageKind kind;
  final String conversationId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int revision;

  factory SearchMessage.fromJson(Map<String, dynamic> json) {
    final kind = switch (json['kind']) {
      'CHANNEL' => SearchMessageKind.channel,
      'DIRECT_MESSAGE' => SearchMessageKind.directMessage,
      _ => throw const FormatException('Invalid search result kind.'),
    };
    final id = json['id'];
    final authorId = json['author_id'];
    final conversationId = kind == SearchMessageKind.channel
        ? json['channel_id']
        : json['direct_message_id'];
    final body = json['body'] as String;
    final revision = json['revision'] as int;
    final createdAt = DateTime.parse(json['created_at'] as String).toLocal();
    final editedAt = json['edited_at'] == null
        ? null
        : DateTime.parse(json['edited_at'] as String).toLocal();
    if (!_isUuid(id) ||
        !_isUuid(authorId) ||
        !_isUuid(conversationId) ||
        body.isEmpty ||
        revision < 1 ||
        (kind == SearchMessageKind.channel &&
            json.containsKey('direct_message_id')) ||
        (kind == SearchMessageKind.directMessage &&
            json.containsKey('channel_id'))) {
      throw const FormatException('Invalid search result.');
    }
    return SearchMessage(
      messageKind: parseMessageKind(json['message_kind']),
      id: id as String,
      kind: kind,
      conversationId: conversationId as String,
      authorId: authorId as String,
      body: body,
      createdAt: createdAt,
      editedAt: editedAt,
      revision: revision,
    );
  }
}

class SearchMessagePage {
  const SearchMessagePage({required this.messages, this.nextCursor});
  final List<SearchMessage> messages;
  final String? nextCursor;
}
