import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS first-frame callback tolerates renderer disposal', () {
    final macosSource = File(
      'macos/flutter_webrtc/Sources/flutter_webrtc/FlutterRTCVideoRenderer.m',
    ).readAsStringSync();
    final callbackStart = macosSource.indexOf(
      '// Notify the Flutter new pixelBufferRef to be ready.',
    );
    expect(callbackStart, isNonNegative);

    final callbackEnd = macosSource.indexOf('\n  });', callbackStart);
    expect(callbackEnd, isNonNegative);
    final callback = macosSource.substring(callbackStart, callbackEnd);

    final nilGuard = callback.indexOf('if (!strongSelf) {');
    final rendererStateAccess = callback.indexOf(
      'strongSelf->_isFirstFrameRendered',
    );
    expect(nilGuard, isNonNegative);
    expect(rendererStateAccess, greaterThan(nilGuard));
  });

  test('shared Darwin and macOS renderer implementations remain identical', () {
    final sharedSource = File(
      'common/darwin/Classes/FlutterRTCVideoRenderer.m',
    ).readAsStringSync();
    final macosSource = File(
      'macos/flutter_webrtc/Sources/flutter_webrtc/FlutterRTCVideoRenderer.m',
    ).readAsStringSync();

    expect(macosSource, sharedSource);
  });
}
