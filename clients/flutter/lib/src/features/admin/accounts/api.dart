import 'dart:convert';

import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class AdminAccountsApi {
  AdminAccountsApi(this.transport);
  final ApiTransport transport;

  Future<AdminAccountPage> listAdminAccounts({
    String? cursor,
    int limit = 100,
  }) async {
    if (limit < 1 ||
        limit > 100 ||
        (cursor != null && (cursor.isEmpty || cursor.length > 512))) {
      throw const ApiFailure('Некорректный курсор участников.');
    }
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/admin/accounts', {
          'limit': '$limit',
          'cursor': ?cursor,
        }),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    final rawAccounts = data['accounts'];
    final nextCursor = data['next_cursor'];
    if (rawAccounts is! List ||
        (nextCursor != null &&
            (nextCursor is! String ||
                nextCursor.isEmpty ||
                nextCursor.length > 512))) {
      throw const ApiFailure('Сервер вернул некорректный список участников.');
    }
    return AdminAccountPage(
      accounts: rawAccounts
          .map((value) => AdminAccount.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
      nextCursor: nextCursor as String?,
    );
  }

  Future<void> updateAdminAccount({
    required String accountId,
    required String role,
    required bool blocked,
    DateTime? expectedUpdatedAt,
  }) async {
    if (accountId.isEmpty || (role != 'MEMBER' && role != 'ADMINISTRATOR')) {
      throw const ApiFailure('Некорректные роль или участник.');
    }
    await transport.checked(
      await transport.client.patch(
        transport.uri('/admin/accounts/${Uri.encodeComponent(accountId)}'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          'role': role,
          'blocked': blocked,
          if (expectedUpdatedAt != null)
            'expected_updated_at': expectedUpdatedAt.toUtc().toIso8601String(),
        }),
      ),
    );
  }
}
