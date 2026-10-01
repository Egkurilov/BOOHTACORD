import 'dart:typed_data';

import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AttachmentUploadFacade on ApiFacadeBase {
  late final _attachmentUpload = AttachmentUploadApi(transport);

  Future<MessageAttachment> uploadChannelAttachment(
    String channelId,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) => transport.run(
    () => _attachmentUpload.uploadChannelAttachment(
      channelId,
      fileName,
      bytes,
      onProgress: onProgress,
    ),
  );

  Future<MessageAttachment> uploadDirectMessageAttachment(
    String directMessageId,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) => transport.run(
    () => _attachmentUpload.uploadDirectMessageAttachment(
      directMessageId,
      fileName,
      bytes,
      onProgress: onProgress,
    ),
  );
}
