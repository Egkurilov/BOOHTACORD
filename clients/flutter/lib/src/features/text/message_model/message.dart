import 'attachments.dart';
import 'kind.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.deleted,
    required this.revision,
    this.clientMessageId,
    this.sendStatus,
    this.replyToId,
    this.mentionUserIds = const [],
    this.attachments = const [],
    this.editedAt,
    this.kind = 'USER',
  });
  final String kind;
  final String id;
  final String channelId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final bool deleted;
  final int revision;
  final String? clientMessageId;
  final MessageSendStatus? sendStatus;
  final String? replyToId;
  final List<String> mentionUserIds;
  final List<MessageAttachment> attachments;
  final DateTime? editedAt;
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    kind: parseMessageKind(json['kind']),
    id: json['id'] as String,
    channelId: json['channel_id'] as String,
    authorId: json['author_id'] as String,
    body: json['body'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    deleted: json['deleted'] as bool? ?? false,
    revision: json['revision'] as int,
    clientMessageId: json['client_message_id'] as String?,
    replyToId: json['reply_to_id'] as String?,
    mentionUserIds: (json['mention_user_ids'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    attachments: parseMessageAttachments(json['attachments']),
    editedAt: json['edited_at'] == null
        ? null
        : DateTime.parse(json['edited_at'] as String).toLocal(),
  );

  ChatMessage withSendStatus(MessageSendStatus status) => ChatMessage(
    kind: kind,
    id: id,
    channelId: channelId,
    authorId: authorId,
    body: body,
    createdAt: createdAt,
    deleted: deleted,
    revision: revision,
    clientMessageId: clientMessageId,
    sendStatus: status,
    replyToId: replyToId,
    mentionUserIds: mentionUserIds,
    attachments: attachments,
    editedAt: editedAt,
  );

  ChatMessage asDeleted() => ChatMessage(
    kind: kind,
    id: id,
    channelId: channelId,
    authorId: authorId,
    body: '',
    createdAt: createdAt,
    deleted: true,
    revision: revision + 1,
    clientMessageId: clientMessageId,
    replyToId: replyToId,
  );
}
