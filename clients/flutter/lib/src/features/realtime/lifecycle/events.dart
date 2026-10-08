import 'dart:convert';

import 'controller.dart';
import '../social_hints/hints.dart';

extension RealtimeEvents on RealtimeController {
  void receive(dynamic raw) {
    if (!admission()() || raw is! String) return;
    try {
      final event = jsonDecode(raw) as Map<String, dynamic>;
      final eventId = event['event_id'] as String?;
      final kind = event['kind'] as String?;
      final payload = event['payload'] as Map<String, dynamic>? ?? const {};
      if (eventId == null || !eventIds.add(eventId)) return;
      if (eventIds.length > 1000) eventIds.clear();
      if (kind == 'connection.ready') {
        connected = true;
        hadConnection = true;
        handshake?.step('ready');
        handshake?.finish('success');
        handshake = null;
      }
      final socialEvent = RealtimeEvent(eventId, kind, payload);
      if (SocialHints.forTransport(api.transport).receive(socialEvent)) return;
      dispatch(
        RealtimeEvent(
          eventId,
          kind,
          payload,
          telemetry: RealtimeTelemetry.parse(event['telemetry']),
        ),
      );
      changed();
    } catch (_) {
      // Unknown/malformed events confer no authority.
    }
  }
}
