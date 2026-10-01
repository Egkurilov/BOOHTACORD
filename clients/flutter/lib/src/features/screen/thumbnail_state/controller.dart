import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/screen_thumbnail.dart';
import 'sample.dart';

class ScreenThumbnailController {
  ScreenThumbnailController(
    this.scope, {
    required this.readRoom,
    required this.isSharing,
    required this.thumbnails,
    required this.queue,
    required this.changed,
    Future<Uint8List> Function(LocalVideoTrack)? capture,
    Future<Uint8List?> Function(Uint8List)? encode,
  }) : capture = capture ?? captureTrack,
       encode = encode ?? encodeFrame;
  final SessionScope scope;
  final Room? Function() readRoom;
  final bool Function() isSharing;
  final Map<String, Uint8List> thumbnails;
  final ScreenThumbnailCaptureQueue queue;
  final void Function() changed;
  final Future<Uint8List> Function(LocalVideoTrack) capture;
  final Future<Uint8List?> Function(Uint8List) encode;
  Timer? timer;
  LocalVideoTrack? track;
  int revision = 0;
  int? busy;
  ScreenThumbnailCaptureResult? lastLoggedResult;
  static Future<Uint8List> captureTrack(LocalVideoTrack track) async =>
      (await track.mediaStreamTrack.captureFrame()).asUint8List();
  static Future<Uint8List?> encodeFrame(Uint8List frame) =>
      compute(encodeScreenThumbnail, frame);
  void start(Room room, LocalVideoTrack track) {
    stop();
    this.track = track;
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(sample(room, track));
    });
    unawaited(sample(room, track));
  }

  void stop() {
    revision++;
    timer?.cancel();
    timer = null;
    track = null;
    busy = null;
    lastLoggedResult = null;
  }
}
