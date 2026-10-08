import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
export 'package:boohtacord_desktop/src/features/voice/roster_state/controller.dart';

class RosterApi extends ApiClient {
  final streams = <Completer<http.StreamedResponse>>[];
  Completer<List<VoiceRoomRoster>>? snapshotResponse;
  @override
  Future<List<VoiceRoomRoster>> voiceParticipants() => snapshotResponse!.future;
  @override
  Future<http.StreamedResponse> voiceRosterEvents() {
    final result = Completer<http.StreamedResponse>();
    streams.add(result);
    return result.future;
  }
}

class ScheduledRosterTimer implements Timer {
  ScheduledRosterTimer(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  bool active = true;
  void fire() {
    if (active) {
      active = false;
      callback();
    }
  }

  @override
  void cancel() => active = false;
  @override
  bool get isActive => active;
  @override
  int get tick => active ? 0 : 1;
}

class RosterHarness {
  final api = RosterApi();
  final scope = SessionScope();
  final timers = <ScheduledRosterTimer>[];
  late final owner = VoiceRosterController(
    api,
    scope,
    isReady: () => true,
    hasUser: () => true,
    message: (e) => '$e',
    retryBudget: 2,
    jitter: () => .5,
    schedule: (d, cb) {
      final timer = ScheduledRosterTimer(d, cb);
      timers.add(timer);
      return timer;
    },
  );
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  Future<StreamController<List<int>>> connect() async {
    final stream = StreamController<List<int>>();
    api.streams.last.complete(http.StreamedResponse(stream.stream, 200));
    await flush();
    return stream;
  }

  void snapshot(
    StreamController<List<int>> stream, {
    bool empty = false,
  }) => stream.add(
    utf8.encode(
      'data: {"channels":${empty ? '[]' : '[{"channel_id":"voice-1","participants":[]}]'}}\n\n',
    ),
  );
}
