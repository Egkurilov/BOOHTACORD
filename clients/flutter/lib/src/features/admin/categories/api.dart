import 'dart:convert';

import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';
import '../topology_validation/validate.dart';

class AdminCategoriesApi {
  AdminCategoriesApi(this.transport);
  final ApiTransport transport;

  Future<void> createCategory(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.runes.length > 80) {
      throw const ApiFailure('Введите название раздела до 80 символов.');
    }
    await transport.checked(
      await transport.client.post(
        transport.uri('/admin/categories'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'name': name}),
      ),
    );
  }

  Future<void> renameCategory({
    required String categoryId,
    required String name,
    required int expectedRevision,
  }) async {
    validateAdminName(name, 'раздела');
    if (categoryId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure('Обновите список разделов и повторите действие.');
    }
    await transport.checked(
      await transport.client.patch(
        transport.uri('/admin/categories/${Uri.encodeComponent(categoryId)}'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'name': name, 'expected_revision': expectedRevision}),
      ),
    );
  }

  Future<void> deleteEmptyCategory({
    required String categoryId,
    required int expectedRevision,
  }) async {
    if (categoryId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure('Обновите список разделов и повторите действие.');
    }
    await transport.checked(
      await transport.client.delete(
        transport.uri('/admin/categories/${Uri.encodeComponent(categoryId)}', {
          'expected_revision': '$expectedRevision',
        }),
        headers: await transport.headers(),
      ),
    );
  }
}
