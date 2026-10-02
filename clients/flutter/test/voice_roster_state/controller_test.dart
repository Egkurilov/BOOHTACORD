import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class DelayedRosterApi extends ApiClient {
  final response = Completer<http.StreamedResponse>();
  @override
  Future<http.StreamedResponse> voiceRosterEvents() => response.future;
}

void main() {
  test(
    'an old watcher cannot clear a replacement stream subscription',
    () async {
      final api = DelayedRosterApi();
      final scope = SessionScope();
      final owner = VoiceRosterController(
        api,
        scope,
        isReady: () => true,
        hasUser: () => true,
        message: (cause) => cause.toString(),
      );
      addTearDown(owner.dispose);
      final oldDone = Completer<void>();
      owner.watching = true;
      owner.revision = 1;
      final stream = StreamController<List<int>>();
      api.response.complete(http.StreamedResponse(stream.stream, 200));
      final watching = owner.watch(1);
      await Future<void>.delayed(Duration.zero);
      final previous = owner.subscription;
      final done = owner.streamDone!;
      owner.revision = 2;
      final replacement = const Stream<String>.empty().listen((_) {});
      owner.subscription = replacement;
      owner.streamDone = oldDone;
      done.complete();
      await watching;
      expect(owner.subscription, same(replacement));
      expect(owner.streamDone, same(oldDone));
      await previous?.cancel();
      await stream.close();
    },
  );
  test(
    'a roster stream admitted before logout is cancelled on arrival',
    () async {
      final api = DelayedRosterApi();
      final scope = SessionScope();
      final owner = VoiceRosterController(
        api,
        scope,
        isReady: () => true,
        hasUser: () => true,
        message: (cause) => cause.toString(),
      );
      addTearDown(owner.dispose);
      owner.start();
      scope.close();
      owner.stop();
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      api.response.complete(http.StreamedResponse(stream.stream, 200));
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      expect(owner.voiceRosters, isNull);
    },
  );
}
