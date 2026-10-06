import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/session.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/action.dart';
import 'package:boohtacord_desktop/src/features/telemetry/observe_render/messages.dart';

void main() {
  testWidgets(
    'sender and receiver observers close only after a mounted frame',
    (tester) async {
      final session = TelemetrySession(
        SessionScope().capture,
        () => 'https://synthetic.invalid',
      );
      session.bind('1' * 32, '1');
      final records = <Map<String, Object>>[];
      final send = ActionScope('message.send', session, observe: records.add);
      final receive = ActionScope(
        'realtime.process',
        session,
        observe: records.add,
      );
      final message = Object();
      awaitMessageRender(message, send);
      awaitMessageRender(message, receive);
      expect(send.complete, false);
      expect(receive.complete, false);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              observeMessageRender(message, context);
              return const Text('synthetic');
            },
          ),
        ),
      );
      expect(send.complete, true);
      expect(receive.complete, true);
      expect(
        records.where((r) => r['app.flow.outcome'] == 'success').length,
        2,
      );
      await tester.pump();
      expect(
        records.where((r) => r['app.flow.outcome'] == 'success').length,
        2,
      );
    },
  );
  testWidgets('old account callback cannot complete as the next account', (
    tester,
  ) async {
    final session = TelemetrySession(
      SessionScope().capture,
      () => 'https://synthetic.invalid',
    );
    session.bind('1' * 32, '1');
    final records = <Map<String, Object>>[];
    final action = ActionScope('message.send', session, observe: records.add),
        message = Object();
    awaitMessageRender(message, action);
    session.reset();
    session.bind('2' * 32, '1');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            observeMessageRender(message, context);
            return const Text('synthetic');
          },
        ),
      ),
    );
    expect(records.where((r) => r['app.flow.outcome'] == 'success'), isEmpty);
  });
}
