import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class AdminAuditApi {
  AdminAuditApi(this.transport);
  final ApiTransport transport;

  Future<AdminAuditPage> listAdminAudit({
    String? before,
    int limit = 100,
  }) async {
    if (limit < 1 ||
        limit > 100 ||
        (before != null && (before.isEmpty || before.length > 512))) {
      throw const ApiFailure('Некорректный курсор аудита.');
    }
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/admin/audit', {'limit': '$limit', 'before': ?before}),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    final rawEvents = data['events'];
    final cursor = data['next_cursor'];
    if (rawEvents is! List ||
        (cursor != null &&
            (cursor is! String || cursor.isEmpty || cursor.length > 512))) {
      throw const ApiFailure('Сервер вернул некорректный список аудита.');
    }
    return AdminAuditPage(
      events: rawEvents
          .map(
            (value) => AdminAuditEvent.fromJson(value as Map<String, dynamic>),
          )
          .toList(growable: false),
      nextCursor: cursor as String?,
    );
  }
}
