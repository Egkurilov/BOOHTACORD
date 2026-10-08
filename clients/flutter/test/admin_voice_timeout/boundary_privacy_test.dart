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
  for (final boundary in ['logout', 'same-account', 'server']) {
    for (final action in ['none', 'apply', 'lift']) {
      testWidgets(
        '$boundary removes previous target from actual route, confirmation=$action',
        (tester) async {
          final changed = ValueNotifier(0);
          addTearDown(changed.dispose);
          final methods = <String>[];
          final api = ApiClient(
            client: MockClient((request) async {
              methods.add(request.method);
              return http.Response(
                jsonEncode({
                  'active': true,
                  'revoked_leases': 1,
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showAdminVoiceTimeout(
                      context,
                      api: api,
                      accountId: '11111111-1111-4111-8111-111111111111',
                      displayName: 'Previous private target',
                      scopeChanges: changed,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.text('Previous private target'), findsOneWidget);
          if (action != 'none') {
            final label = action == 'lift'
                ? 'Снять ограничение'
                : 'Ограничить голос';
            await tester.ensureVisible(find.text(label));
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
            expect(
              find.textContaining('Previous private target'),
              findsNWidgets(2),
            );
          }
          if (boundary == 'server') {
            api.baseUrl = 'https://different.invalid/api/v1';
          } else {
            api.transport.session.scope.close();
            if (boundary == 'same-account') api.transport.session.scope.begin();
          }
          changed.value++;
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Previous private target', skipOffstage: false),
            findsNothing,
          );
          expect(
            find.textContaining('Преследование', skipOffstage: false),
            findsNothing,
          );
          expect(
            find.textContaining('ожидает подтверждения', skipOffstage: false),
            findsNothing,
          );
          expect(
            find.byType(DropdownButtonFormField<int>, skipOffstage: false),
            findsNothing,
          );
          expect(find.text('Подтвердить'), findsNothing);
          expect(methods, ['GET']);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
