import 'package:flutter/foundation.dart';

import '../../../core/http/api_failure.dart';
import '../../guild/profile/model.dart';
import 'model.dart';

class GuildSettingsController extends ChangeNotifier {
  GuildSettingsController(this.read, this.write);
  final Future<GuildSettings> Function() read;
  final Future<GuildSettings> Function(String, String?, int) write;
  String name = '';
  String? welcome, error;
  int revision = 0;
  bool busy = false, saved = false, _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    busy = true;
    error = null;
    _notify();
    try {
      final row = await read();
      if (_disposed) return;
      name = row.name;
      welcome = row.welcome;
      revision = row.revision;
    } catch (_) {
      if (!_disposed) error = 'Не удалось загрузить настройки.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> save(List<String> available) async {
    if (_disposed || busy || revision == 0) return;
    error = null;
    saved = false;
    if (!validGuildName(name.trim())) {
      error = 'Название: от 1 до 80 символов, без переводов строк.';
      _notify();
      return;
    }
    if (welcome != null && !available.contains(welcome)) {
      error = 'Выберите доступный текстовый канал или выключите приветствия.';
      _notify();
      return;
    }
    busy = true;
    _notify();
    try {
      final row = await write(name.trim(), welcome, revision);
      if (_disposed) return;
      name = row.name;
      welcome = row.welcome;
      revision = row.revision;
      saved = true;
    } catch (cause) {
      if (_disposed) return;
      error = 'Не удалось сохранить настройки.';
      if (cause is ApiFailure && cause.status == 409) {
        error = 'Настройки изменил другой администратор. Проверьте черновик и сохраните снова.';
        try {
          final row = await read();
          if (!_disposed) revision = row.revision;
        } catch (_) {
          if (!_disposed) {
            revision = 0;
            error = 'Перечитайте настройки перед повторной попыткой.';
          }
        }
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
