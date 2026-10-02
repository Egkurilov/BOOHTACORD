import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/src/native/media_stream_impl.dart';
import 'package:flutter_webrtc/src/native/rtc_video_renderer_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('late clear response cannot hide a stream attached through srcObject',
      () async {
    final methodChannel = MethodChannel('FlutterWebRTC.Method');
    final eventChannel = MethodChannel('FlutterWebRTC/Texture23');
    final clearResult = Completer<void>();
    final streamResult = Completer<void>();
    final clearInvoked = Completer<void>();
    final streamInvoked = Completer<void>();
    Future<Object?> handleMethod(MethodCall call) async {
      switch (call.method) {
        case 'initialize':
          return null;
        case 'createVideoRenderer':
          return {'textureId': 23};
        case 'videoRendererSetSrcObject':
          final arguments = call.arguments as Map<dynamic, dynamic>;
          if (arguments['streamId'] == '') {
            clearInvoked.complete();
            await clearResult.future;
            return null;
          }
          streamInvoked.complete();
          await streamResult.future;
          return null;
        case 'videoRendererDispose':
          return null;
        default:
          fail('Unexpected method ${call.method}');
      }
    }

    methodChannel.setMockMethodCallHandler(handleMethod);
    eventChannel.setMockMethodCallHandler((_) async => null);
    addTearDown(() {
      methodChannel.setMockMethodCallHandler(null);
      eventChannel.setMockMethodCallHandler(null);
    });

    final renderer = RTCVideoRenderer();
    await renderer.initialize();

    renderer.srcObject = null;
    renderer.srcObject = MediaStreamNative('stream-new', 'remote');
    await Future.wait([clearInvoked.future, streamInvoked.future]);
    renderer.eventListener(<String, Object>{
      'event': 'didTextureChangeVideoSize',
      'width': 640,
      'height': 360,
    });

    streamResult.complete();
    await pumpEventQueue();
    expect(renderer.value.renderVideo, isTrue);
    expect(renderer.videoWidth, 640);

    clearResult.complete();
    await pumpEventQueue();
    expect(renderer.srcObject?.id, 'stream-new');
    expect(renderer.value.renderVideo, isTrue);
    expect(renderer.videoWidth, 640);

    await renderer.dispose();
  });
}
