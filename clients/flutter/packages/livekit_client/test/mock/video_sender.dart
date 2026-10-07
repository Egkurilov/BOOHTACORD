// Copyright 2026 LiveKit, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/src/track/local/video.dart';
import 'package:livekit_client/src/track/options.dart';
import 'package:livekit_client/src/types/other.dart';

class TestVideoSender implements rtc.RTCRtpSender {
  TestVideoSender(List<rtc.RTCRtpEncoding> encodings)
    : _parameters = rtc.RTCRtpParameters(encodings: encodings);

  rtc.RTCRtpParameters _parameters;
  final started = Completer<void>();
  final release = Completer<void>();
  var writes = 0;
  var inFlight = 0;
  var maxInFlight = 0;

  @override
  rtc.RTCRtpParameters get parameters => _parameters;

  @override
  Future<bool> setParameters(rtc.RTCRtpParameters parameters) async {
    writes++;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    if (writes == 1) {
      started.complete();
      await release.future;
    }
    _parameters = parameters;
    inFlight--;
    return true;
  }

  @override
  String get senderId => 'test-screen-sender';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestVideoTransceiver implements rtc.RTCRtpTransceiver {
  TestVideoTransceiver(this.sender);

  @override
  final rtc.RTCRtpSender sender;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

LocalVideoTrack testScreenTrack(TestVideoSender sender) {
  final stream = _TestMediaStream();
  final mediaTrack = _TestMediaStreamTrack();
  final track = LocalVideoTrack(
    TrackSource.screenShareVideo,
    stream,
    mediaTrack,
    const ScreenShareCaptureOptions(),
  );
  track.transceiver = TestVideoTransceiver(sender);
  return track;
}

class _TestMediaStream implements rtc.MediaStream {
  @override
  String get id => 'test-screen-stream';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestMediaStreamTrack implements rtc.MediaStreamTrack {
  @override
  String get id => 'test-screen-track';

  @override
  String get kind => 'video';

  @override
  rtc.StreamTrackCallback? onEnded;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
