import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  test('native rendered-frame event notifies renderer listener', () {
    final renderer = RTCVideoRenderer();
    var notifications = 0;
    renderer.onFirstFrameRendered = () => notifications++;

    renderer.eventListener(<String, Object>{
      'event': 'didFirstFrameRendered',
      'id': 1,
    });

    expect(notifications, 1);
  });
}
