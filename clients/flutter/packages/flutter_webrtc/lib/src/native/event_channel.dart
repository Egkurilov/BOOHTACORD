import 'dart:async';

import 'package:flutter/services.dart';

class FlutterWebRTCEventChannel {
  FlutterWebRTCEventChannel._internal() {
    EventChannel('FlutterWebRTC.Event')
        .receiveBroadcastStream()
        .listen(eventListener, onError: errorListener);
  }

  static final FlutterWebRTCEventChannel instance =
      FlutterWebRTCEventChannel._internal();

  final StreamController<Map<String, dynamic>> handleEvents =
      StreamController.broadcast();

  Stream<CapturedContentVisibilityEvent> get capturedContentVisibilityEvents =>
      handleEvents.stream
          .map(CapturedContentVisibilityEvent.fromChannelEvent)
          .where((event) => event != null)
          .cast<CapturedContentVisibilityEvent>();

  void eventListener(dynamic event) async {
    final Map<dynamic, dynamic> map = event;
    handleEvents.add(<String, dynamic>{map['event'] as String: map});
  }

  void errorListener(Object obj) {
    if (obj is Exception) {
      throw obj;
    }
  }
}

class CapturedContentVisibilityEvent {
  const CapturedContentVisibilityEvent(this.trackId, this.isVisible);

  final String trackId;
  final bool isVisible;

  static CapturedContentVisibilityEvent? fromChannelEvent(
    Map<String, dynamic> message,
  ) {
    final event = message['onCapturedContentVisibilityChanged'];
    if (event is! Map) return null;
    final trackId = event['trackId'];
    final isVisible = event['isVisible'];
    if (trackId is! String || trackId.isEmpty || isVisible is! bool) {
      return null;
    }
    return CapturedContentVisibilityEvent(trackId, isVisible);
  }
}
