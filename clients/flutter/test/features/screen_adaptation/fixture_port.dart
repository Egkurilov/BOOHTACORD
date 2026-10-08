import 'dart:async';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/screen/runtime_apply/port.dart';

import 'fixtures.dart';

class FixturePort implements ScreenAdaptationPort {
  final scope = SessionScope();
  Object room = Object(), track = Object();
  int manual = 0, writer = 0, generation = 1, writes = 0;
  bool stopped = false, succeeds = true;
  var current = high;
  Completer<bool>? pending;
  @override
  ScreenRuntimeBinding? read() => stopped
      ? null
      : ScreenRuntimeBinding(
          ticket: scope.capture(),
          transportTicket: scope.capture(),
          server: 0,
          room: room,
          track: track,
          publication: 'synthetic',
          lifecycle: 0,
          writerRevision: writer,
          manualRevision: manual,
          generation: generation,
          current: current,
          ceiling: high,
        );
  @override
  bool canApply(target, binding) => true;
  @override
  Future<bool> write(target) async {
    writes++;
    writer++;
    await pending?.future;
    if (!succeeds) return false;
    current = target;
    return true;
  }
}
