import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/src/widgets/video_track_renderer_frame_callback.dart';

void main() {
  test('first-frame callback is attached and cleared with the renderer', () {
    final renderer = rtc.RTCVideoRenderer();
    var notifications = 0;

    setVideoTrackRendererFirstFrameCallback(
      renderer,
      () => notifications++,
    );
    renderer.eventListener(<String, Object>{
      'event': 'didFirstFrameRendered',
      'id': 1,
    });

    expect(notifications, 1);

    setVideoTrackRendererFirstFrameCallback(renderer, null);
    renderer.eventListener(<String, Object>{
      'event': 'didFirstFrameRendered',
      'id': 1,
    });

    expect(notifications, 1);
  });
}
