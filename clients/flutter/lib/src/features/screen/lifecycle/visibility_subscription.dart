import 'dart:async';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

StreamSubscription<rtc.CapturedContentVisibilityEvent>?
subscribeCapturedVisibility(
  void Function(rtc.CapturedContentVisibilityEvent) handle,
) => Platform.isAndroid
    ? rtc.FlutterWebRTCEventChannel.instance.capturedContentVisibilityEvents
          .listen(handle)
    : null;
