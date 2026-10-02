import 'dart:typed_data';

import '../../features/conversation/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppAttachmentsAccess on AppOwners {
  Future<MessageAttachment> uploadAttachment(
    String fileName,
    Uint8List bytes, {
    String? channelId,
    String? directMessageId,
    void Function(int sent, int total)? onProgress,
  }) => conversation.uploadAttachment(
    fileName,
    bytes,
    channelId: channelId,
    directMessageId: directMessageId,
    onProgress: onProgress,
  );
}
