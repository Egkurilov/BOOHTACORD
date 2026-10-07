import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../../../core/session/scope.dart';
import '../../../services/api_client.dart';
import '../profile/quality.dart';
import '../../../services/screen_thumbnail.dart';
import '../capture/driver.dart';
import '../metrics/factory.dart';
import '../thumbnail_state/controller.dart';
import '../../voice/screen_preview/client.dart';
import '../../voice/screen_preview/uploader.dart';
import 'captured_content_visibility.dart';
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
    metrics = createScreenShareMetricsController(api, scope,
      readRoom: readRoom, isSharing: () => phase == ScreenSharePhase.sharing,
      readQuality: () => quality, changed: changed);
    thumbnail = ScreenThumbnailController(
      scope,
      readRoom: readRoom,
      isSharing: () => phase == ScreenSharePhase.sharing,
      thumbnails: thumbnails,
      queue: captureQueue,
      changed: changed,
      previewUploader: LatestScreenPreviewUploader(
        ScreenPreviewClient(api.transport),
      ),
    );
    if (Platform.isAndroid) {
      _capturedContentVisibilitySubscription = rtc
          .FlutterWebRTCEventChannel
          .instance
          .capturedContentVisibilityEvents
          .listen(handleCapturedContentVisibility);
    }
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
  final CapturedContentVisibilityState capturedContentVisibility =
      CapturedContentVisibilityState();
  StreamSubscription<rtc.CapturedContentVisibilityEvent>?
  _capturedContentVisibilitySubscription;
  ScreenSharePhase phase = ScreenSharePhase.idle;
  String? error;
  ScreenShareQuality quality =
      defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS
      ? ScreenShareQuality.balanced
      : ScreenShareQuality.desktopDefault;
  int revision = 0;
  int qualityIntentRevision = 0;
  ScreenShareQuality? pendingQualityUpdate;
  SessionTicket? pendingQualityTicket;
  Room? pendingQualityRoom;
  int pendingQualityLifecycleRevision = 0;
  Future<void>? qualityUpdateOperation;
  bool disposed = false;
  Future<void>? starting;
  Future<void>? closing;
  LocalVideoTrack? activeTrack;
  VideoDimensions? sourceDimensions;
  bool? get capturedContentVisible => capturedContentVisibility.isVisible;

  void handleCapturedContentVisibility(
    rtc.CapturedContentVisibilityEvent event,
  ) {
    if (capturedContentVisibility.handle(event)) changed();
  }

  bool current(SessionTicket ticket, int expected, Room room) =>
      !disposed &&
      ticket.isActive &&
      expected == revision &&
      identical(readRoom(), room);
  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> stopSampling() async {
    metrics.stop();
    await thumbnail.stop();
  }

  Future<void> previewLeaseChanged(String? leaseId) =>
      thumbnail.changeLease(leaseId);

  @override
  void dispose() {
    disposed = true;
    unawaited(_capturedContentVisibilitySubscription?.cancel());
    unawaited(stopScreenShare());
    super.dispose();
  }
}
