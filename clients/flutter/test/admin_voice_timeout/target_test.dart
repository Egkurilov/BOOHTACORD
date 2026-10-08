import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/admin_voice_timeout/dialog.dart';

const first = '11111111-1111-4111-8111-111111111111',
    second = '22222222-2222-4222-8222-222222222222';
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('changing actual dialog target excludes earlier active state', (
    tester,
  ) async {
    final previous = Completer<http.Response>();
    final calls = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        calls.add(request.url.path);
        return request.url.path.contains(first)
            ? previous.future
            : http.Response(
                jsonEncode({
                  'active': false,
                  'revoked_leases': 0,
                  'revocation_pending': false,
                }),
                200,
              );
      }),
    );
    Widget surface(String id) => MaterialApp(
      home: Scaffold(
        body: AdminVoiceTimeoutDialog(
          api: api,
          accountId: id,
          displayName: 'Synthetic member',
        ),
      ),
    );
    await tester.pumpWidget(surface(first));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(surface(second));
    await tester.pumpAndSettle();
    previous.complete(
      http.Response(
        jsonEncode({
          'active': true,
          'revoked_leases': 3,
          'revocation_pending': true,
          'expires_at': '2026-10-10T00:00:00Z',
          'reason_code': 'OTHER',
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(calls.length, 2);
    expect(find.text('Ограничение не активно.'), findsOneWidget);
    expect(find.text('Снять ограничение'), findsNothing);
    expect(find.textContaining('ожидает подтверждения'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
