import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android forwards profile bounds into its MediaProjection capturer', () {
    final sourceRoot =
        'packages/flutter_webrtc/android/src/main/java/com/cloudwebrtc/webrtc';
    final getUserMedia =
        File('$sourceRoot/GetUserMediaImpl.java').readAsStringSync();
    final requestParser =
        File('$sourceRoot/ScreenCaptureConstraints.java').readAsStringSync();
    final capturerPath = '$sourceRoot/OrientationAwareScreenCapturer.java';
    final capturer = File(capturerPath).readAsStringSync();

    expect(
      getUserMedia,
      contains('ScreenCaptureConstraints.from(constraints)'),
    );
    expect(getUserMedia, contains('maximumDimension, maximumFrameRate'));
    expect(getUserMedia, contains('new OrientationAwareScreenCapturer('));
    expect(requestParser, contains('constraints.getMap("video")'));
    expect(capturer, contains('ScreenCaptureDimensions.forOutput('));
    expect(
      capturer,
      contains('frameRateGate.shouldForward(System.nanoTime())'),
    );
  });
}
