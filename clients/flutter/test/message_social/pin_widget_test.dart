import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/text_pins/component.dart';
import 'package:boohtacord_desktop/src/features/realtime/social_hints/hints.dart';

const channel = '11111111-1111-4111-8111-111111111111',
    message = '22222222-2222-4222-8222-222222222222',
    author = '33333333-3333-4333-8333-333333333333';
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'actual TEXT pins preserve original ID, literal preview and admin unpin',
    (tester) async {
      final methods = <String>[];
      var pinned = true;
      String? opened;
      final transport = ApiTransport(
        client: MockClient((request) async {
          if (request.method == 'DELETE') {
            methods.add(request.method);
            pinned = false;
            return http.Response('', 204);
          }
          return http.Response(
            jsonEncode({
              'can_manage': true,
              'pins': pinned
                  ? [
                      {
                        'message_id': message,
                        'author_id': author,
                        'preview': '<script>unsafe()</script>',
                        'pinned_at': '2026-10-09T12:01:00Z',
                        'message_created_at': '2026-10-09T12:00:00Z',
                      },
                    ]
                  : [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextPinsPanel(
              transport: transport,
              channel: channel,
              onOpen: (pin) {
                opened = pin.messageId;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('<script>unsafe()</script>'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('text-pin:$message')));
      expect(opened, message);
      await tester.tap(find.text('Снять закрепление'));
      await tester.pumpAndSettle();
      expect(methods, ['DELETE']);
      expect(find.text('Закреплений пока нет.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(SocialHints.forTransport(transport).observerCount, 0);
    },
  );
  testWidgets('member pin list has no unpin control and errors allow retry', (
    tester,
  ) async {
    var status = 403;
    final transport = ApiTransport(
      client: MockClient(
        (_) async => http.Response(
          status == 200 ? jsonEncode({'can_manage': false, 'pins': []}) : '',
          status,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextPinsPanel(
            transport: transport,
            channel: channel,
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('403'), findsOneWidget);
    expect(find.text('Снять закрепление'), findsNothing);
    status = 200;
    await tester.tap(find.text('Обновить закрепления'));
    await tester.pumpAndSettle();
    expect(find.text('Закреплений пока нет.'), findsOneWidget);
  });
}
