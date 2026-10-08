import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/message_social/component.dart';
import 'package:boohtacord_desktop/src/features/realtime/social_hints/hints.dart';

const channel = '11111111-1111-4111-8111-111111111111',
    message = '22222222-2222-4222-8222-222222222222';
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('DM controls have six reactions and no TEXT pin authority', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final transport = ApiTransport(
      client: MockClient((request) async {
        requests.add(request);
        return request.method == 'GET'
            ? http.Response(
                jsonEncode({'reactions': [], 'can_pin': false}),
                200,
              )
            : http.Response('', 204);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageSocialControls(
            transport: transport,
            direct: true,
            conversation: channel,
            message: message,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsNWidgets(6));
    expect(find.text('Закрепить сообщение'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reaction:👍')));
    await tester.pumpAndSettle();
    expect(
      requests.singleWhere((r) => r.method == 'PUT').url.path,
      contains('/direct-messages/$channel/messages/$message/reactions/'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(SocialHints.forTransport(transport).observerCount, 0);
  });
  testWidgets('disposed or replaced conversation ignores earlier HTTP result', (
    tester,
  ) async {
    final first = Completer<http.Response>();
    var calls = 0;
    final transport = ApiTransport(
      client: MockClient((_) async {
        calls++;
        return calls == 1
            ? await first.future
            : http.Response(
                jsonEncode({'reactions': [], 'can_pin': false}),
                200,
              );
      }),
    );
    Widget controls(String id) => MaterialApp(
      home: Scaffold(
        body: MessageSocialControls(
          transport: transport,
          direct: true,
          conversation: channel,
          message: id,
        ),
      ),
    );
    await tester.pumpWidget(controls(message));
    await tester.pump();
    await tester.pumpWidget(controls(channel));
    await tester.pumpAndSettle();
    first.complete(
      http.Response(
        jsonEncode({
          'reactions': [
            {'message_id': message, 'emoji': '👍', 'count': 7, 'mine': true},
          ],
          'can_pin': false,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('👍 7'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(SocialHints.forTransport(transport).observerCount, 0);
  });
}
