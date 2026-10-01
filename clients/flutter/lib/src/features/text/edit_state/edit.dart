import '../../conversation/lifecycle/controller.dart';

extension ConversationEditTextWithResult on ConversationController {
  Future<MessageEditOutcome> editTextWithResult(
    ChatMessage message,
    String body,
    int expectedRevision, {
    List<String>? mentionUserIds,
  }) async {
    final active = admission(selection: true);
    if (!active()) {
      return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
    }
    final trimmed = body.trim();
    if (selectedChannel?.id != message.channelId ||
        !messages.any((item) => item.id == message.id)) {
      return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
    }
    if (trimmed.isEmpty || trimmed.runes.length > 8000) {
      return (
        kind: MessageEditStatus.error,
        message: 'Сообщение должно содержать до 8000 символов.',
      );
    }
    try {
      final edited = await api.editMessage(
        message.channelId,
        message.id,
        trimmed,
        expectedRevision,
        mentionUserIds: mentionUserIds ?? message.mentionUserIds,
      );
      if (!active()) {
        return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
      }
      if (selectedChannel?.id != message.channelId) {
        return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
      }
      messages = messages
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
      if (selectedChannel?.id == message.channelId) {
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
