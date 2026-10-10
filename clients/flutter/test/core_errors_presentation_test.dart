import 'dart:async';

import 'package:boohtacord_desktop/src/core/errors/presentation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('translates offline and timeout failures into actionable feedback', () {
    expect(
      appFailureMessage(http.ClientException('Failed to fetch')),
      'Нет соединения с сервером. Проверьте подключение.',
    );
    expect(
      appFailureMessage(TimeoutException('timeout')),
      'Сервер не ответил вовремя. Повторите попытку.',
    );
  });
}
