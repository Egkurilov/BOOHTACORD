import 'controller.dart';

extension ProfileEditing on ProfileController {
  Future<bool> saveDisplayName(String value) async {
    if (disposed || !scope.capture().isActive) return false;
    if (value.runes.isEmpty || value.runes.length > 64) {
      error('Имя должно содержать от 1 до 64 символов.');
      changed();
      return false;
    }
    return save((active) async {
      final result = await api.updateOwnProfile(value);
      if (!active()) return;
      acceptProfile(result);
      await refreshMembers();
    });
  }

  Future<bool> updatePassword(String current, String next) async {
    if (disposed || !scope.capture().isActive) return false;
    if (current.runes.length < 12 ||
        current.runes.length > 128 ||
        next.runes.length < 12 ||
        next.runes.length > 128) {
      error('Пароль должен содержать от 12 до 128 символов.');
      changed();
      return false;
    }
    return save((_) => api.changePassword(current, next));
  }
}
