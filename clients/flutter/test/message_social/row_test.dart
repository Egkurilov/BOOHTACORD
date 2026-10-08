import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/message_row/component.dart';
import 'package:boohtacord_desktop/src/features/realtime/social_hints/hints.dart';

const channel = '11111111-1111-4111-8111-111111111111',
    messageId = '22222222-2222-4222-8222-222222222222',
    author = '33333333-3333-4333-8333-333333333333';
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'actual TEXT row retains body and binds six idempotent reactions with cleanup',
    (tester) async {
      final methods = <String>[];
      var present = false;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/message-reactions')) {
            return http.Response(
              jsonEncode({
                'can_pin': false,
                'reactions': present
                    ? [
                        {
                          'message_id': messageId,
                          'emoji': '👍',
                          'count': 1,
                          'mine': true,
                        },
                      ]
                    : [],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          methods.add(request.method);
          present = request.method == 'PUT';
          return http.Response('', 204);
        }),
      );
      final state = AppState(api);
      addTearDown(state.dispose);
      final message = ChatMessage(
        id: messageId,
        channelId: channel,
        authorId: author,
        body: 'Original text',
        createdAt: DateTime.utc(2026, 10, 9),
        deleted: false,
        revision: 1,
        clientMessageId: author,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceMessageRow(state: state, message: message),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Original text'), findsOneWidget);
      expect(find.byKey(const ValueKey('reaction:👍')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reaction:👍')));
      await tester.pumpAndSettle();
      expect(find.text('👍 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reaction:👍')));
      await tester.pumpAndSettle();
      expect(methods, ['PUT', 'DELETE']);
      final bus = SocialHints.forTransport(api.transport);
      expect(bus.observerCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(bus.observerCount, 0);
    },
  );
}
