import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/driver.dart';
import 'package:boohtacord_desktop/src/services/screen_share_quality.dart';

class FakeScreenRoom implements Room {
  @override
  final LocalParticipant localParticipant = FakeScreenParticipant();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScreenParticipant implements LocalParticipant {
  @override
  String get identity => 'local';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScreenTrack implements LocalVideoTrack {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DelayedScreenDriver implements ScreenShareDriver {
  final captured = Completer<LocalVideoTrack>();
  Completer<void>? publication;
  int published = 0;
  final stopped = <LocalVideoTrack>[];
  final removed = <LocalVideoTrack>[];
  @override
  Future<void> prepare(bool Function() active) async {}
  @override
  Future<LocalVideoTrack> capture(ScreenShareCaptureOptions options) =>
      captured.future;
  @override
  Future<void> publish(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
  ) async {
    published++;
    await publication?.future;
  }

  @override
  Future<void> discard(Room room, LocalVideoTrack track) async {
    removed.add(track);
    stopped.add(track);
  }

  @override
  Future<void> stop(Room room) async {}
  @override
  Future<void> disableBackground() async {}
}
