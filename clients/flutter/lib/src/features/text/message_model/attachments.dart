class MessageAttachment {
  const MessageAttachment({
    required this.id,
    required this.originalName,
    required this.sizeBytes,
  });
  final String id;
  final String originalName;
  final int sizeBytes;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    final size = json['byte_size'];
    final id = json['id'];
    final originalName = json['original_name'];
    if (id is! String ||
        id.isEmpty ||
        originalName is! String ||
        originalName.isEmpty ||
        size is! int ||
        size < 0 ||
        size > 25000000) {
      throw const FormatException('Invalid message attachment size.');
    }
    return MessageAttachment(
      id: id,
      originalName: originalName,
      sizeBytes: size,
    );
  }
}

enum MessageSendStatus { sending, checking, failed }

List<MessageAttachment> parseMessageAttachments(Object? value) {
  if (value == null) return const [];
  if (value is! List) {
    throw const FormatException('Invalid message attachments.');
  }
  if (value.length > 10) {
    throw const FormatException('Too many message attachments.');
  }
  return value
      .map((item) => MessageAttachment.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
}
