import 'dart:typed_data';

import '../../conversation/lifecycle/controller.dart';

extension ConversationUploadAttachment on ConversationController {
  Future<MessageAttachment> uploadAttachment(
    String fileName,
    Uint8List bytes, {
    String? channelId,
    String? directMessageId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final active = admission();
    void ensureActive() {
      if (!active()) {
        throw const ApiFailure(
          'Сессия изменилась. Повторите загрузку.',
          code: 'STALE_SESSION',
        );
      }
    }

    void progress(int sent, int total) {
      if (active()) onProgress?.call(sent, total);
    }

    ensureActive();
    if ((channelId == null) == (directMessageId == null)) {
      throw const ApiFailure('Выберите беседу для вложения.');
    }
    final MessageAttachment result;
    if (directMessageId != null) {
      result = await api.uploadDirectMessageAttachment(
        directMessageId,
        fileName,
        bytes,
        onProgress: progress,
      );
    } else {
      result = await api.uploadChannelAttachment(
        channelId!,
        fileName,
        bytes,
        onProgress: progress,
      );
    }
    ensureActive();
    return result;
  }
}
