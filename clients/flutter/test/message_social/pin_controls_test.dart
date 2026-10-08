import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/event.dart';
import 'package:boohtacord_desktop/src/features/realtime/social_hints/hints.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/message_social/component.dart';

const channel = '11111111-1111-4111-8111-111111111111',
    message = '22222222-2222-4222-8222-222222222222';
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('TEXT pin control rechecks ACL after mutation and recovery', (
    tester,
  ) async {
    var canPin = true, reads = 0;
    final mutations = <http.Request>[];
    final transport = ApiTransport(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          reads++;
          return http.Response(
            jsonEncode({'reactions': [], 'can_pin': canPin}),
            200,
          );
        }
        mutations.add(request);
        canPin = false;
        return http.Response('', 204);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageSocialControls(
            transport: transport,
            direct: false,
            conversation: channel,
            message: message,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закрепить сообщение'));
    await tester.pumpAndSettle();
    expect(mutations.single.method, 'PUT');
    expect(mutations.single.body, isEmpty);
    expect(
      mutations.single.url.path,
      '/api/v1/admin/text-channels/$channel/pins/$message',
    );
    expect(reads, 2);
    expect(find.text('Закрепить сообщение'), findsNothing);
    final hints = SocialHints.forTransport(transport);
    canPin = true;
    hints.receive(
      const RealtimeEvent('recovery', 'connection.resync_required', {}),
    );
    await tester.pumpAndSettle();
    expect(reads, 3);
    expect(find.text('Закрепить сообщение'), findsOneWidget);
    hints.receive(
      RealtimeEvent('invalid', 'message.pins_updated', {
        'channel_id': channel,
        'message_id': message,
        'body': 'unexpected private payload',
      }),
    );
    await tester.pumpAndSettle();
    expect(reads, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(hints.observerCount, 0);
  });
}
