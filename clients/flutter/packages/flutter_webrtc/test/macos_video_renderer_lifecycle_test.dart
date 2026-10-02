import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS first-frame callback waits until a texture buffer is uploaded',
      () {
    final macosSource = File(
      'macos/flutter_webrtc/Sources/flutter_webrtc/FlutterRTCVideoRenderer.m',
    ).readAsStringSync();
    final renderStart = macosSource.indexOf(
      '- (void)renderFrame:(RTCVideoFrame*)frame {',
    );
    final renderEnd = macosSource.indexOf('\n- (void)setSize:', renderStart);
    expect(renderStart, isNonNegative);
    expect(renderEnd, greaterThan(renderStart));
    final renderMethod = macosSource.substring(renderStart, renderEnd);

    final uploadedFlag = renderMethod.indexOf('BOOL didUploadFrame = NO;');
    final uploadGuard = renderMethod.indexOf('if (didUploadFrame) {');
    final textureNotification = renderMethod.indexOf(
      'textureFrameAvailable:_textureId',
    );
    final uploadCompletion = renderMethod.indexOf('didUploadFrame = YES;');
    final firstFrameEvent = renderMethod.indexOf('didFirstFrameRendered');

    expect(uploadedFlag, isNonNegative);
    expect(textureNotification, greaterThan(uploadedFlag));
    expect(uploadCompletion, greaterThan(textureNotification));
    expect(uploadGuard, greaterThan(uploadCompletion));
    expect(firstFrameEvent, greaterThan(uploadGuard));
  });

  test('macOS first-frame callback tolerates renderer disposal', () {
    final macosSource = File(
      'macos/flutter_webrtc/Sources/flutter_webrtc/FlutterRTCVideoRenderer.m',
    ).readAsStringSync();
    final callbackStart = macosSource.indexOf(
      "// Report first frame only after a pixel buffer was uploaded to Flutter's texture.",
    );
    expect(callbackStart, isNonNegative);

    final callbackEnd = macosSource.indexOf('\n    });', callbackStart);
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
