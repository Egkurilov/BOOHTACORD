import 'dart:convert';

import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class AdminPasswordResetApi {
  AdminPasswordResetApi(this.transport);
  final ApiTransport transport;

  Future<AdminPasswordResetLink> createAdminPasswordResetLink(
    String accountId,
  ) async {
    if (accountId.isEmpty) {
      throw const ApiFailure('Выберите участника для сброса пароля.');
    }
    final data = await transport.checked(
      await transport.client.post(
        transport.uri('/admin/password-reset-links'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'account_id': accountId}),
      ),
    ) as Map<String, dynamic>;
    final url = data['url'];
    final expiresAt = data['expires_at'];
    if (url is! String || url.isEmpty || expiresAt is! String) {
      throw const ApiFailure(
        'Сервер вернул некорректную ссылку сброса пароля.',
      );
    }
    return AdminPasswordResetLink(
      url: url,
      expiresAt: DateTime.parse(expiresAt).toLocal(),
    );
  }
}
