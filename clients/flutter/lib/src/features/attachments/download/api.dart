import 'dart:typed_data';

import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class AttachmentDownloadApi {
  AttachmentDownloadApi(this.transport);
  final ApiTransport transport;

  Future<Uint8List> messageAttachmentBytes(
    String parentPath,
    String attachmentId, {
    bool preview = false,
  }) async {
    final response = await transport.client.get(
      transport.uri(
        '$parentPath/attachments/${Uri.encodeComponent(attachmentId)}${preview ? '/preview' : ''}',
      ),
      headers: await transport.headers(accept: preview ? 'image/*' : '*/*'),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    await transport.checked(response);
    throw const ApiFailure('Не удалось загрузить вложение.');
  }
}
