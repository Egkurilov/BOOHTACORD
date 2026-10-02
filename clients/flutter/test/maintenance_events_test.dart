import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:boohtacord_desktop/src/features/session/maintenance_state/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/maintenance_events.dart';

class MaintenanceStreamApi extends ApiClient {
  MaintenanceStreamApi(this.body);
  final StreamController<List<int>> body;
  int requests = 0;

  @override
  Future<http.StreamedResponse> maintenanceEvents() async {
    requests++;
    return http.StreamedResponse(body.stream, 200);
  }
}

void main() {
  test('parses only public maintenance state frames', () {
    expect(parseMaintenanceEvent(': keepalive'), isNull);
    expect(parseMaintenanceEvent('event: ignored'), isNull);
    expect(parseMaintenanceEvent('data: {"active":true}'), isTrue);
    expect(parseMaintenanceEvent('data: {"active":false}'), isFalse);
    expect(
      () => parseMaintenanceEvent('data: {"active":"true"}'),
      throwsFormatException,
    );
  });

  test(
    'keeps one maintenance SSE subscription and closes it on dispose',
    () async {
      var canceled = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          canceled = true;
        },
      );
      final api = MaintenanceStreamApi(body);
      final controller = MaintenanceController(
        api,
        retryDelay: const Duration(milliseconds: 10),
      );
      final changed = Completer<void>();
      controller.addListener(() {
        if (controller.active && !changed.isCompleted) changed.complete();
      });

      controller.start();
      controller.start();
      await Future<void>.delayed(Duration.zero);
      expect(api.requests, 1);
      body.add(utf8.encode('data: {"active":true}\n\n'));
      await changed.future.timeout(const Duration(seconds: 1));
      expect(controller.active, isTrue);

      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(canceled, isTrue);
      await body.close();
    },
  );
}
