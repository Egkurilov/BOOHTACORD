import 'package:boohtacord_desktop/src/services/password_reset_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseUrl = 'https://v.bootybay.ru/api/v1';
  final token = List.filled(43, 'a').join();

  test('extracts the one-use secret from the same-origin URL fragment', () {
    expect(
      parsePasswordResetToken(
        baseUrl,
        'https://v.bootybay.ru/reset-password#token=$token',
      ),
      token,
    );
  });

  test('rejects secrets in query strings and links from another origin', () {
    expect(
      parsePasswordResetToken(
        baseUrl,
        'https://v.bootybay.ru/reset-password?token=$token',
      ),
      isNull,
    );
    expect(
      parsePasswordResetToken(
        baseUrl,
        'https://attacker.example/reset-password#token=$token',
      ),
      isNull,
    );
  });

  test('rejects malformed and duplicate fragment values', () {
    expect(
      parsePasswordResetToken(
        baseUrl,
        'https://v.bootybay.ru/reset-password#token=short',
      ),
      isNull,
    );
    expect(
      parsePasswordResetToken(
        baseUrl,
        'https://v.bootybay.ru/reset-password#token=$token&token=$token',
      ),
      isNull,
    );
  });
}
