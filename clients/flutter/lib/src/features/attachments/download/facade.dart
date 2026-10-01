import 'dart:typed_data';

import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AttachmentDownloadFacade on ApiFacadeBase {
  late final _attachmentDownload = AttachmentDownloadApi(transport);

  Future<Uint8List> messageAttachmentBytes(
    String parentPath,
    String attachmentId, {
    bool preview = false,
  }) => transport.run(
    () => _attachmentDownload.messageAttachmentBytes(
      parentPath,
      attachmentId,
      preview: preview,
    ),
  );
}
