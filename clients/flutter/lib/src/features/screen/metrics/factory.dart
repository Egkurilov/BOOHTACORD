import 'package:livekit_client/livekit_client.dart';

import '../../../core/session/scope.dart';
import '../../../services/api_client.dart';
import '../profile/quality.dart';
import 'controller.dart';

export 'controller.dart' show ScreenShareMetricsController;

ScreenShareMetricsController createScreenShareMetricsController(
  ApiClient api,
  SessionScope scope, {
  required Room? Function() readRoom,
  required bool Function() isSharing,
  required ScreenShareQuality Function() readQuality,
  required void Function() changed,
}) => ScreenShareMetricsController(
  api,
  scope,
  readRoom: readRoom,
  isSharing: isSharing,
  readQuality: readQuality,
  changed: changed,
);
