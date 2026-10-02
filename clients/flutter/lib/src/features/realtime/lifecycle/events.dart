import 'dart:convert';

import 'controller.dart';

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
      if (kind == 'connection.ready') connected = true;
      dispatch(RealtimeEvent(eventId, kind, payload));
      changed();
    } catch (_) {
      // Unknown/malformed events confer no authority.
    }
  }
}
