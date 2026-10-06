import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/client_telemetry.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/action.dart';
import 'package:boohtacord_desktop/src/features/telemetry/observe_render/messages.dart';

void main() {
  testWidgets(
    'native Flutter SDK and frame observation survive real relay and Tempo',
    (tester) async {
      final env = Platform.environment;
      final relay = Uri.parse(env['TRACE_QA_RELAY_URL']!);
      expect(relay.scheme, 'http');
      expect(relay.host, '127.0.0.1');
      final previousHttp = HttpOverrides.current;
      HttpOverrides.global = null; // Opt-in private runtime: use real sockets.
      addTearDown(() => HttpOverrides.global = previousHttp);
      FlutterSecureStorage.setMockInitialValues({});
      final api = ApiClient();
      api.transport.session.baseUrl = '${relay.origin}/api/v1';
      final session = api.transport.session.telemetry;
      session.bind(env['TRACE_QA_SESSION'], '1');
      ClientTelemetry.session = session;
      await tester.runAsync(
        () => ClientTelemetry.initialize(api.submitClientSpans),
      );
      final action = ActionScope('message.send', session, enabled: true),
          message = Object();
      action.step('request');
      awaitMessageRender(message, action);
      expect(action.complete, false);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              observeMessageRender(message, context);
              return const Text('private-synthetic-message');
            },
          ),
        ),
      );
      expect(action.complete, true);
      final traceID = action.span!.spanContext.traceId.toString();
      await tester.runAsync(() async {
        await OTel.shutdown();
        final client = http.Client();
        try {
          final deadline = DateTime.now().add(const Duration(seconds: 20));
          while (DateTime.now().isBefore(deadline)) {
            final response = await client.get(
              Uri.parse('${env['TRACE_QA_TEMPO_URL']}/api/traces/$traceID'),
            );
            if (response.statusCode == 200) {
              expect(jsonDecode(response.body), isNotNull);
              expect(response.body, contains(action.id));
              expect(response.body, contains('success'));
              expect(
                response.body,
                isNot(contains('private-synthetic-message')),
              );
              stdout.writeln(
                'native synthetic stored trace=$traceID; mounted-frame terminal; host=${Platform.operatingSystem}',
              );
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
          fail('accepted native export absent from actual Tempo');
        } finally {
          client.close();
          api.transport.raw.close();
        }
      });
    },
    skip: Platform.environment['TRACE_QA_NATIVE'] != '1',
  );
}
