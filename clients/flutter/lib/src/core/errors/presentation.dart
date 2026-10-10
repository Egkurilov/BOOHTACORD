import 'dart:async' as async;

import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:http/http.dart' as http;

import '../http/api_failure.dart';

String appFailureMessage(Object cause) {
  if (cause is ApiFailure) return cause.message;
  if (cause is http.ClientException) {
    return 'Нет соединения с сервером. Проверьте подключение.';
  }
  if (cause is async.TimeoutException) {
    return 'Сервер не ответил вовремя. Повторите попытку.';
  }
  if (cause is PlatformException) {
    final code = String.fromCharCodes(
      cause.code.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '').runes.take(80),
    );
    var detail = (cause.message ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAllMapped(
          RegExp(
            r'(password|token|cookie|authorization)\s*[:=]\s*\S+',
            caseSensitive: false,
          ),
          (match) => '${match[1]}=[скрыто]',
        );
    final detailRunes = detail.runes.toList(growable: false);
    if (detailRunes.length > 240) {
      detail = '${String.fromCharCodes(detailRunes.take(240))}…';
    }
    final context = [
      if (code.isNotEmpty) code,
      if (detail.isNotEmpty) detail,
    ].join(' — ');
    return context.isEmpty
        ? 'Ошибка системного API.'
        : 'Ошибка системного API: $context';
  }
  if (cause is ConnectException) {
    final code = cause.statusCode > 0 ? ' (${cause.statusCode})' : '';
    return switch (cause.reason) {
      ConnectionErrorReason.NotAllowed =>
        'LiveKit отклонил подключение$code. Голосовой lease освобождён.',
      ConnectionErrorReason.Timeout =>
        'LiveKit не ответил вовремя. Голосовой lease освобождён.',
      ConnectionErrorReason.InternalError =>
        'Не удалось подключиться к LiveKit$code: ${cause.message}',
    };
  }
  if (cause is MediaConnectException) {
    return 'Не удалось установить WebRTC-соединение: ${cause.message}';
  }
  if (cause is LiveKitException) return 'Ошибка LiveKit: ${cause.message}';
  return 'Не удалось выполнить действие: ${cause.runtimeType}.';
}
