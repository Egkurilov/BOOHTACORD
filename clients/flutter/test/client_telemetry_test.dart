import 'dart:convert';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/client_telemetry.dart';
import 'package:boohtacord_desktop/src/services/tracing_http_client.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/telemetry/action_scope/session.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/proto/opentelemetry_proto_dart.dart'
    as proto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'manual spans propagate trace context without request secrets',
    () async {
      final exports = <Uint8List>[];
      ClientTelemetry.session = TelemetrySession(
        SessionScope().capture,
        () => 'https://example.test',
      );
      ClientTelemetry.session!.bind('11111111111111111111111111111111', '1');
      await ClientTelemetry.initialize((body) async => exports.add(body));
      String? propagated;
      final client = TracingHttpClient(
        MockClient((request) async {
          propagated = request.headers['traceparent'];
          return http.Response('private-response-sentinel', 200);
        }),
      );

      await ClientTelemetry.trace('voice.join', () async {
        final response = await client.post(
          Uri.parse('https://example.test/api?private-query-sentinel=1'),
          headers: {'authorization': 'private-token-sentinel'},
          body: 'private-body-sentinel',
        );
        expect(response.statusCode, 200);
        await Future<void>.delayed(Duration.zero);
        await client.get(Uri.parse('https://example.test/api/second'));
      });
      await ClientTelemetry.trace(
        'screen.share.start',
        () async {},
        failed: () => true,
      );
      String? websocketParent;
      await ClientTelemetry.trace('realtime.connect', () async {
        await Future<void>.delayed(Duration.zero);
        websocketParent = ClientTelemetry.currentTraceparent();
      });
      ClientTelemetry.audioInputSwitch('active', 'success');
      ClientTelemetry.audioInputSwitch('private-device', 'private-label');
      await OTel.shutdown();

      expect(propagated, matches(RegExp(r'^00-[0-9a-f]{32}-[0-9a-f]{16}-01$')));
      final encoded = exports.expand((body) => body).toList();
      final serialized = latin1.decode(encoded);
      expect(serialized, contains('voice.join'));
      expect(serialized, contains('api.request'));
      final spans = exports
          .expand(
            (body) =>
                proto.ExportTraceServiceRequest.fromBuffer(body).resourceSpans,
          )
          .expand((resource) => resource.scopeSpans)
          .expand((scope) => scope.spans)
          .where(
            (span) =>
                !span.attributes.any((a) => a.key == 'app.flow.record') ||
                span.attributes.any(
                  (a) =>
                      a.key == 'app.flow.record' &&
                      a.value.stringValue == 'terminal',
                ) ||
                span.name == 'api.request',
          );
      final voice = spans.singleWhere((span) => span.name == 'voice.join');
      final input = spans.singleWhere(
        (span) => span.name == 'audio.input.switch',
      );
      expect(input.attributes.map((attribute) => attribute.key).toSet(), {
        'platform',
        'phase',
        'result',
        'session.id',
      });
      expect(serialized, isNot(contains('private-device')));
      expect(serialized, isNot(contains('private-label')));
      final apiSpans = spans
          .where((span) => span.name == 'api.request')
          .toList();
      final realtime = spans.singleWhere(
        (span) => span.name == 'realtime.connect',
      );
      expect(apiSpans, hasLength(2));
      for (final api in apiSpans) {
        expect(api.traceId, voice.traceId);
        expect(api.parentSpanId, voice.spanId);
      }
      final traceId = realtime.traceId
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      final spanId = realtime.spanId
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      expect(websocketParent, '00-$traceId-$spanId-01');
      expect(
        spans
            .singleWhere((span) => span.name == 'screen.share.start')
            .status
            .code
            .value,
        2,
      );
      expect(
        spans
            .singleWhere((span) => span.name == 'voice.join')
            .events
            .map((event) => event.name),
        ['app.client.voice.join.started', 'app.client.voice.join.completed'],
      );
      expect(
        spans
            .singleWhere((span) => span.name == 'screen.share.start')
            .events
            .map((event) => event.name),
        [
          'app.client.screen.share.start.started',
          'app.client.screen.share.start.failed',
        ],
      );
      for (final secret in [
        'private-query-sentinel',
        'private-token-sentinel',
        'private-body-sentinel',
        'private-response-sentinel',
      ]) {
        expect(serialized, isNot(contains(secret)));
      }
    },
  );
}
