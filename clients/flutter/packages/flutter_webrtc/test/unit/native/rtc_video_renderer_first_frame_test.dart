import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  test('native rendered-frame event notifies renderer listener', () {
    final renderer = RTCVideoRenderer();
    var notifications = 0;
    renderer.onFirstFrameRendered = () => notifications++;
    // The initial binding generation is zero before the first srcObject bind.

    renderer.eventListener(<String, Object>{
      'event': 'didFirstFrameRendered',
      'id': 1,
      'sourceGeneration': 0,
    });

    expect(notifications, 1);
  });
}
