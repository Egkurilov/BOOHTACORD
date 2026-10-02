import '../../conversation/lifecycle/controller.dart';

extension ConversationEditDirectWithResult on ConversationController {
  Future<MessageEditOutcome> editDirectWithResult(
    DirectChatMessage message,
    String body,
    int expectedRevision, {
    List<String>? mentionUserIds,
  }) async {
    final active = admission(selection: true);
    if (!active()) {
      return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
    }
    final trimmed = body.trim();
    if (selectedDirectMessage?.id != message.directMessageId ||
        !directMessageHistory.any((item) => item.id == message.id)) {
      return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
    }
    if (trimmed.isEmpty || trimmed.runes.length > 8000) {
      return (
        kind: MessageEditStatus.error,
        message: 'Сообщение должно содержать до 8000 символов.',
      );
    }
    try {
      final edited = await api.editDirectMessage(
        message.directMessageId,
        message.id,
        trimmed,
        expectedRevision,
        mentionUserIds: mentionUserIds ?? message.mentionUserIds,
      );
      if (!active()) {
        return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
      }
      if (selectedDirectMessage?.id != message.directMessageId) {
        return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
      }
      directMessageHistory = directMessageHistory
          .map((value) => value.id == edited.id ? edited : value)
          .toList(growable: false);
      error = null;
      changed();
      return (kind: MessageEditStatus.saved, message: null);
    } catch (cause) {
      if (!active()) {
        return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
      }
      final conflict = cause is ApiFailure && cause.status == 409;
      final messageText = conflict
          ? 'Сообщение изменилось. Обновите версию, чтобы сохранить свой текст.'
          : formatError(cause);
      if (selectedDirectMessage?.id == message.directMessageId) {
        error = messageText;
        changed();
      }
      return (
        kind: conflict ? MessageEditStatus.conflict : MessageEditStatus.error,
        message: messageText,
      );
    }
  }
}
