import 'dart:async';
import '../../../core/http/api_failure.dart';

bool uncertainDelivery(Object cause) {
  final status = cause is ApiFailure ? cause.status : null;
  return status == null || status >= 500 && status != 507 || status == 408;
}

Future<T> recoverDelivery<T>({
  required Future<T> Function() post,
  required Future<T?> Function() lookup,
  required void Function(String) status,
  required bool Function() active,
  required bool retry,
  Duration timeout = const Duration(seconds:20),
}) async {
  void ensure() {
    if (!active()) throw StateError('Сеанс изменился. Отправка остановлена.');
  }

  Future<T?> check() async {
    ensure();
    status('checking');
    final found = await lookup().timeout(timeout);
    ensure();
    return found;
  }

  if (retry) {
    final found = await check();
    if (found != null) return found;
  }
  ensure();
  status('sending');
  try {
    final result = await post().timeout(timeout);
    ensure();
    return result;
  } catch (cause) {
    ensure();
    if (uncertainDelivery(cause)) {
      final found = await check();
      if (found != null) return found;
    }
    rethrow;
  }
}
