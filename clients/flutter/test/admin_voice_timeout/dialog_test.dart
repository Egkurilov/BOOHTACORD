import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/admin_voice_timeout/dialog.dart';

const account = '11111111-1111-4111-8111-111111111111';
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'actual dialog confirms apply and lift without implying media success',
    (tester) async {
      final requests = <http.Request>[];
      var active = false;
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method != 'GET') active = request.method == 'PUT';
          return http.Response(
            jsonEncode({
              'active': active,
              'revoked_leases': 1,
              'revocation_pending': request.method != 'GET',
              if (active)
                'expires_at': DateTime.now()
                    .toUtc()
                    .add(const Duration(minutes: 5))
                    .toIso8601String(),
              if (active) 'reason_code': 'DISRUPTION',
            }),
            request.method == 'PUT' ? 202 : 200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAdminVoiceTimeout(
                  context,
                  api: api,
                  accountId: account,
                  displayName: 'Synthetic member',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(requests.single.method, 'GET');
      await tester.tap(find.text('Ограничить голос'));
      await tester.pumpAndSettle();
      expect(requests.length, 1);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(requests.length, 1);
      await tester.tap(find.text('Ограничить голос'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(requests.map((r) => r.method), ['GET', 'PUT']);
      expect(find.textContaining('ожидает подтверждения'), findsOneWidget);
      expect(
        find.textContaining('Отключено логических подключений: 1'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Снять ограничение'));
      await tester.tap(find.text('Снять ограничение'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Подтвердить'));
      await tester.pumpAndSettle();
      expect(requests.map((r) => r.method), ['GET', 'PUT', 'DELETE']);
      expect(find.text('Ограничение не активно.'), findsOneWidget);
      expect(find.textContaining('новое подключение вручную'), findsOneWidget);
      await tester.ensureVisible(find.text('Закрыть'));
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    },
  );
}
