import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/api_client.dart';
import '../../../services/screen_share_quality.dart';
import '../../../services/screen_thumbnail.dart';
import '../capture/driver.dart';
import '../metrics/controller.dart';
import '../thumbnail_state/controller.dart';
import 'stop.dart';
import 'types.dart';
export 'types.dart';
export 'start.dart';
export 'stop.dart';
export 'events.dart';
export '../quality/update.dart';

class ScreenShareController extends ChangeNotifier {
  ScreenShareController(
    this.api,
    this.scope, {
    required this.readRoom,
    required this.voiceReady,
    ScreenShareDriver? driver,
  }) : driver = driver ?? NativeScreenShareDriver() {
    metrics = ScreenShareMetricsController(
      api,
      scope,
      readRoom: readRoom,
      isSharing: () => phase == ScreenSharePhase.sharing,
      readQuality: () => quality,
    );
    thumbnail = ScreenThumbnailController(
      scope,
      readRoom: readRoom,
      isSharing: () => phase == ScreenSharePhase.sharing,
      thumbnails: thumbnails,
      queue: captureQueue,
      changed: changed,
    );
  }
  final ApiClient api;
  final SessionScope scope;
  final Room? Function() readRoom;
  final bool Function() voiceReady;
  final ScreenShareDriver driver;
  late final ScreenShareMetricsController metrics;
  late final ScreenThumbnailController thumbnail;
  final Map<String, Uint8List> thumbnails = {};
  final captureQueue = ScreenThumbnailCaptureQueue();
  ScreenSharePhase phase = ScreenSharePhase.idle;
  String? error;
  ScreenShareQuality quality =
      defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS
      ? ScreenShareQuality.balanced
      : ScreenShareQuality.desktopDefault;
  int revision = 0;
  bool disposed = false;
  Future<void>? starting;
  Future<void>? closing;
  LocalVideoTrack? activeTrack;
  bool current(SessionTicket ticket, int expected, Room room) =>
      !disposed &&
      ticket.isActive &&
      expected == revision &&
      identical(readRoom(), room);
  void changed() {
    if (!disposed) notifyListeners();
  }

  void stopSampling() {
    metrics.stop();
    thumbnail.stop();
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(stopScreenShare());
    super.dispose();
  }
}
