import 'dart:typed_data';

import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class AvatarApi {
  AvatarApi(this.transport);
  final ApiTransport transport;

  Future<Uint8List> avatarBytes(String avatarUrl) async {
    final response = await transport.client.get(
      _avatarUri(avatarUrl),
      headers: await transport.headers(accept: 'image/png'),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    await transport.checked(response);
    throw const ApiFailure('Не удалось загрузить аватар.');
  }

  Future<void> uploadOwnAvatar(Uint8List bytes, String contentType) async {
    await transport.checked(
      await transport.client.put(
        transport.uri('/me/avatar'),
        headers: {
          ...await transport.headers(accept: 'application/json'),
          'content-type': contentType,
        },
        body: bytes,
      ),
    );
  }

  Future<void> deleteOwnAvatar() async {
    await transport.checked(
      await transport.client.delete(
        transport.uri('/me/avatar'),
        headers: await transport.headers(),
      ),
    );
  }

  Uri _avatarUri(String value) {
    final base = Uri.parse(transport.session.baseUrl);
    final resolved = base.resolveUri(Uri.parse(value));
    final expectedPrefix = '${base.path}/members/';
    if (resolved.scheme != 'https' ||
        resolved.scheme != base.scheme ||
        resolved.host != base.host ||
        resolved.port != base.port ||
        !resolved.path.startsWith(expectedPrefix) ||
        !resolved.path.endsWith('/avatar')) {
      throw const ApiFailure('Сервер вернул недопустимый адрес аватара.');
    }
    return resolved;
  }
}
