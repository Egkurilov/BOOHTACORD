import 'package:livekit_client/livekit_client.dart' show VideoDimensions;

import '../../../../services/screen_share_quality.dart';

class ScreenShareSetupSelection {
  const ScreenShareSetupSelection({
    required this.sourceId,
    required this.quality,
    this.sourceDimensions,
  });

  final String? sourceId;
  final ScreenShareQuality quality;
  final VideoDimensions? sourceDimensions;
}
