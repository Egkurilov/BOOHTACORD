import 'dart:typed_data';

import '../avatar/normalize_image.dart';
import 'controller.dart';

extension ProfileAvatar on ProfileController {
  Future<bool> uploadAvatar(Uint8List bytes, String contentType) async {
    if (disposed || !scope.capture().isActive) return false;
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      error('Выберите изображение размером не более 2 МиБ.');
      changed();
      return false;
    }
    final normalized = normalizeAvatarImage(bytes, contentType);
    if (normalized == null) {
      error(
        'Не удалось обработать изображение. Выберите PNG или JPEG до 2 МиБ.',
      );
      changed();
      return false;
    }
    return save((active) async {
      await api.uploadOwnAvatar(normalized, 'image/png');
      if (!active()) return;
      await _refreshAvatar(active);
    });
  }

  Future<bool> deleteAvatar() => save((active) async {
    await api.deleteOwnAvatar();
    if (!active()) return;
    await _refreshAvatar(active);
  });

  Future<void> _refreshAvatar(bool Function() active) async {
    final result = await api.ownProfile();
    if (!active()) return;
    profile = result;
    avatarRevision++;
    await refreshMembers();
  }
}
