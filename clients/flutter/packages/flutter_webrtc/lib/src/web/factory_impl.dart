import '../desktop_capturer.dart';

export 'package:dart_webrtc/dart_webrtc.dart'
    hide videoRenderer, MediaDevices, MediaRecorder;

DesktopCapturer get desktopCapturer => throw UnimplementedError();

/// WebRTC has no native peer-connection factory to warm on web.
Future<void> ensurePeerConnectionFactoryReady() async {}
