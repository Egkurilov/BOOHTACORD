import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support.dart';

AppState ready(RosterApi api) {
  final state = AppState(
    api,
    voiceRosterRetryDelay: const Duration(milliseconds: 1),
    voiceRosterStaleTimeout: const Duration(milliseconds: 100),
  );
  state.session.scope.begin();
  state.session.user = const SessionUser(
    accountId: 'account-1',
    role: 'MEMBER',
  );
  state.session.phase = AppPhase.ready;
  addTearDown(state.dispose);
  return state;
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

Future<StreamController<List<int>>> connect(RosterApi api) async {
  final stream = StreamController<List<int>>();
  api.streams.last.complete(http.StreamedResponse(stream.stream, 200));
  await flush();
  return stream;
}
