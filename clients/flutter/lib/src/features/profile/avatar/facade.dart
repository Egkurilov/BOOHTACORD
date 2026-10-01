import 'dart:typed_data';

import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AvatarFacade on ApiFacadeBase {
  late final _avatar = AvatarApi(transport);

  Future<Uint8List> avatarBytes(String avatarUrl) =>
      transport.run(() => _avatar.avatarBytes(avatarUrl));

  Future<void> uploadOwnAvatar(Uint8List bytes, String contentType) =>
      transport.run(() => _avatar.uploadOwnAvatar(bytes, contentType));

  Future<void> deleteOwnAvatar() =>
      transport.run(() => _avatar.deleteOwnAvatar());
}
