import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/src/native/media_stream_impl.dart';
import 'package:flutter_webrtc/src/native/rtc_video_renderer_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stale native frame events cannot complete a replacement source', () async {
    final methodChannel = MethodChannel('FlutterWebRTC.Method');
    final eventChannel = MethodChannel('FlutterWebRTC/Texture31');
    final sourceGenerations = <int>[];
    Future<Object?> handleMethod(MethodCall call) async {
      switch (call.method) {
        case 'initialize':
          return null;
        case 'createVideoRenderer':
          return {'textureId': 31};
        case 'videoRendererSetSrcObject':
          sourceGenerations.add(
            (call.arguments as Map<dynamic, dynamic>)['sourceGeneration']
                as int,
          );
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
    var firstFrames = 0;
    renderer.onFirstFrameRendered = () => firstFrames++;

    renderer.srcObject = MediaStreamNative('screen-a', 'remote');
    await pumpEventQueue();
    final oldGeneration = sourceGenerations.single;
    renderer.srcObject = MediaStreamNative('screen-b', 'remote');
    await pumpEventQueue();
    final middleGeneration = sourceGenerations.last;
    renderer.srcObject = MediaStreamNative('screen-a', 'remote');
    await pumpEventQueue();
    final currentGeneration = sourceGenerations.last;
    expect(currentGeneration, greaterThan(oldGeneration));
    expect(currentGeneration, greaterThan(middleGeneration));

    for (final staleGeneration in [oldGeneration, middleGeneration]) {
      renderer.eventListener(<String, Object>{
        'event': 'didTextureChangeVideoSize',
        'sourceGeneration': staleGeneration,
        'width': 1920,
        'height': 1080,
      });
      renderer.eventListener(<String, Object>{
        'event': 'didFirstFrameRendered',
        'sourceGeneration': staleGeneration,
      });
    }

    expect(renderer.videoWidth, 0);
    expect(renderer.videoHeight, 0);
    expect(firstFrames, 0);

    renderer.eventListener(<String, Object>{
      'event': 'didTextureChangeVideoSize',
      'sourceGeneration': currentGeneration,
      'width': 1280,
      'height': 720,
    });
    renderer.eventListener(<String, Object>{
      'event': 'didFirstFrameRendered',
      'sourceGeneration': currentGeneration,
    });
    expect(renderer.videoWidth, 1280);
    expect(renderer.videoHeight, 720);
    expect(firstFrames, 1);

    await renderer.dispose();
    renderer.eventListener(<String, Object>{
      'event': 'didFirstFrameRendered',
      'sourceGeneration': currentGeneration,
    });
    expect(firstFrames, 1);
  });
}
