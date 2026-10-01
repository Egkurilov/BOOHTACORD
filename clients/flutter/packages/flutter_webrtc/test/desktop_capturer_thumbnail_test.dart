import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/src/desktop_capturer.dart' show SourceType;
import 'package:flutter_webrtc/src/native/desktop_capturer_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const eventChannel = MethodChannel('FlutterWebRTC.Event');

  test('preserves a thumbnail event received before getSources completes',
      () async {
    eventChannel.setMockMethodCallHandler((_) async => null);
    addTearDown(() => eventChannel.setMockMethodCallHandler(null));

    final capturer = DesktopCapturerNative.instance;
    const sourceId = 'screen-1';
    final source = <dynamic, dynamic>{
      'id': sourceId,
      'name': 'Screen 1',
      'type': 'screen',
      'thumbnailSize': {'width': 0, 'height': 0},
    };
    final preview = Uint8List.fromList([1, 2, 3]);

    final methodChannel = MethodChannel('FlutterWebRTC.Method');
    methodChannel.setMockMethodCallHandler((call) async {
      if (call.method == 'initialize') return null;
      expect(call.method, 'getDesktopSources');
      // Model native event delivery after getSources cleared its cache but
      // before the method-channel response replaces that cache.
      capturer.handleEvent('desktopSourceAdded', source);
      capturer.handleEvent('desktopSourceThumbnailChanged', {
        ...source,
        'thumbnail': preview,
      });
      return {'sources': [source]};
    });
    addTearDown(() => methodChannel.setMockMethodCallHandler(null));

    final sources = await capturer.getSources(types: [SourceType.Screen]);

    expect(sources, hasLength(1));
    expect(sources.single.thumbnail, preview);
  });
}
