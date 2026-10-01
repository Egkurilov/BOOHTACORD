import 'package:flutter/services.dart';

enum ScreenSharePhase { idle, starting, sharing, stopping, error }

String screenShareFailureDetail(Object cause) {
  if (cause is String && cause.trim().isNotEmpty) return cause.trim();
  if (cause is StateError) return cause.message;
  if (cause is PlatformException) {
    final message = cause.message?.trim();
    if (message != null && message.isNotEmpty) return message;
    final code = cause.code.trim();
    if (code.isNotEmpty) return code;
  }
  final detail = cause.toString().trim();
  if (detail.isNotEmpty && detail != cause.runtimeType.toString()) {
    return detail;
  }
  return cause.runtimeType.toString();
}
