import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/admin_voice_timeout/dialog.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('scope listener immediately hides loaded state after logout', (
    tester,
  ) async {
    final boundary = ValueNotifier(0);
    addTearDown(boundary.dispose);
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'active': true,
            'revoked_leases': 0,
            'revocation_pending': true,
            'expires_at': '2026-10-10T00:00:00Z',
            'reason_code': 'HARASSMENT',
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminVoiceTimeoutDialog(
            api: api,
            accountId: '11111111-1111-4111-8111-111111111111',
            displayName: 'Synthetic member',
            scopeChanges: boundary,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Причина: Преследование'), findsOneWidget);
    api.transport.session.scope.close();
    boundary.value++;
    await tester.pumpAndSettle();
    expect(find.text('Причина: Преследование'), findsNothing);
    expect(find.text('Снять ограничение'), findsNothing);
    expect(find.textContaining('Сессия или сервер изменились'), findsOneWidget);
    expect(calls, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
