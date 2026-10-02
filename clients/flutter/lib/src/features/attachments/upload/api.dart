import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';
import 'progress_request.dart';

class AttachmentUploadApi {
  AttachmentUploadApi(this.transport);
  final ApiTransport transport;

  Future<MessageAttachment> uploadChannelAttachment(
    String channelId,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) => _uploadMessageAttachment(
    '/channels/$channelId/attachments',
    fileName,
    bytes,
    onProgress: onProgress,
  );

  Future<MessageAttachment> uploadDirectMessageAttachment(
    String directMessageId,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) => _uploadMessageAttachment(
    '/direct-messages/$directMessageId/attachments',
    fileName,
    bytes,
    onProgress: onProgress,
  );

  Future<MessageAttachment> _uploadMessageAttachment(
    String path,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) async {
    if (fileName.isEmpty || bytes.length > 25000000) {
      throw const ApiFailure('Файл должен быть не больше 25 МБ.');
    }
    final request = ProgressMultipartRequest(
      'POST',
      transport.uri(path),
      onProgress,
    );
    request.headers.addAll(await transport.headers());
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );
    final response = await http.Response.fromStream(
      await transport.client.send(request),
    );
    final data = await transport.checked(response) as Map<String, dynamic>;
    return MessageAttachment.fromJson(data);
  }
}
