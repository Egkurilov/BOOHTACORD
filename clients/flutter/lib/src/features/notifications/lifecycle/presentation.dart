import 'package:flutter/services.dart';

String? notificationBodyForUnreadIncrease({
  required String kind,
  required int? previousUnread,
  required int? currentUnread,
}) {
  if (previousUnread == null ||
      currentUnread == null ||
      currentUnread <= previousUnread) {
    return null;
  }
  return switch (kind) {
    'message.created' => 'Новое сообщение в канале.',
    'direct_message.message_created' => 'Новое личное сообщение.',
    _ => null,
  };
}

String enabledKey(String accountId) =>
    'boohtacord:notification:$accountId:enabled';

String seenKey(String accountId) => 'boohtacord:notification:$accountId:seen';

int notificationId(String eventId) {
  final normalized = eventId.replaceAll('-', '');
  final prefix = normalized.length >= 8
      ? normalized.substring(0, 8)
      : normalized;
  return (int.tryParse(prefix, radix: 16) ?? eventId.hashCode) & 0x7fffffff;
}

String notificationFailure(Object cause) {
  if (cause is PlatformException && cause.code == 'invalid_icon') {
    return 'Не удалось подготовить значок системного уведомления.';
  }
  if (cause is Exception && cause.toString().startsWith('Exception: ')) {
    return cause.toString().substring('Exception: '.length);
  }
  return cause.toString();
}
