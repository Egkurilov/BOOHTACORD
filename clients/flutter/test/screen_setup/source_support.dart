import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

class FakeDesktopCapturer extends rtc.DesktopCapturer {
  final calls = <Completer<List<rtc.DesktopCapturerSource>>>[];
  @override
  final onAdded = StreamController<rtc.DesktopCapturerSource>.broadcast();
  @override
  final onRemoved = StreamController<rtc.DesktopCapturerSource>.broadcast();
  @override
  final onNameChanged = StreamController<rtc.DesktopCapturerSource>.broadcast();
  @override
  final onThumbnailChanged =
      StreamController<rtc.DesktopCapturerSource>.broadcast();
  @override
  Future<List<rtc.DesktopCapturerSource>> getSources({
    required List<rtc.SourceType> types,
    rtc.ThumbnailSize? thumbnailSize,
  }) {
    final result = Completer<List<rtc.DesktopCapturerSource>>();
    calls.add(result);
    return result.future;
  }

  @override
  Future<bool> updateSources({required List<rtc.SourceType> types}) async =>
      true;
  Future<void> close() async {
    await onAdded.close();
    await onRemoved.close();
    await onNameChanged.close();
    await onThumbnailChanged.close();
  }
}

class FakeSource extends rtc.DesktopCapturerSource {
  FakeSource(this.id, this.type);
  @override
  final String id;
  @override
  final rtc.SourceType type;
  @override
  String get name => id;
  @override
  Uint8List? get thumbnail => null;
  @override
  rtc.ThumbnailSize get thumbnailSize => rtc.ThumbnailSize(640, 360);
}
