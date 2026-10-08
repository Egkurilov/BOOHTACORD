import '../native_bindings.dart';

class WorkspaceSearchContextMessage {
  const WorkspaceSearchContextMessage({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
    required this.deleted,
    required this.attachments,
    this.editedAt,
    this.messageKind = 'USER',
  });
  final String messageKind;
  final String id;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool deleted;
  final List<MessageAttachment> attachments;
}
