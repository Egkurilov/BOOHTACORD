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

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/src/options.dart';
import 'package:livekit_client/src/types/video_dimensions.dart';
import 'package:livekit_client/src/types/video_encoding.dart';
import 'package:livekit_client/src/utils.dart';
import 'package:livekit_client/src/proto/livekit_rtc.pb.dart' as lk_rtc;
import 'package:livekit_client/src/proto/livekit_models.pb.dart' as lk_models;

import '../mock/video_sender.dart';

void main() {
  test('screen-share low simulcast layer is capped at 15 fps', () {
    final encodings = Utils.computeVideoEncodings(
      isScreenShare: true,
      dimensions: VideoDimensions(2560, 1440),
      options: const VideoPublishOptions(
        screenShareEncoding: VideoEncoding(maxFramerate: 60, maxBitrate: 12000000),
      ),
    )!;

    expect(encodings, hasLength(2));
    expect(encodings.map((encoding) => encoding.maxFramerate), [15, 60]);
  });

  test('serializes profile writes with the SDK dynacast sender writer', () async {
    final sender = TestVideoSender([
      rtc.RTCRtpEncoding(rid: 'f', maxBitrate: 8000000, scaleResolutionDownBy: 1),
      rtc.RTCRtpEncoding(rid: 'h', maxBitrate: 2500000, scaleResolutionDownBy: 2),
      rtc.RTCRtpEncoding(rid: 'q', maxBitrate: 800000, scaleResolutionDownBy: 4),
    ]);
    final track = testScreenTrack(sender);
    final dynacast = track.setPublishingLayersForSender(
      sender,
      sender.parameters.encodings!,
      [lk_rtc.SubscribedQuality(quality: lk_models.VideoQuality.HIGH, enabled: false)],
    );
    await sender.started.future;

    final profile = track.setDegradationPreference(
      DegradationPreference.maintainResolution,
    );
    expect(sender.maxInFlight, 1);
    sender.release.complete();
    await Future.wait([dynacast, profile]);

    final encodings = sender.parameters.encodings!;
    expect(sender.maxInFlight, 1);
    expect(encodings.map((encoding) => encoding.rid), ['f', 'h', 'q']);
    expect(encodings.map((encoding) => encoding.active), [false, true, true]);
    expect(encodings.map((encoding) => encoding.maxFramerate), [null, null, null]);
    expect(encodings.map((encoding) => encoding.maxBitrate), [8000000, 2500000, 800000]);
    expect(encodings.map((encoding) => encoding.scaleResolutionDownBy), [1, 2, 4]);
    expect(sender.parameters.degradationPreference, rtc.RTCDegradationPreference.maintainResolution);
  });

  test('republish invalidation drops queued dynacast work for the old sender', () async {
    final sender = TestVideoSender([rtc.RTCRtpEncoding(rid: 'f')]);
    final track = testScreenTrack(sender);
    final first = track.setPublishingLayersForSender(
      sender,
      sender.parameters.encodings!,
      [lk_rtc.SubscribedQuality(quality: lk_models.VideoQuality.HIGH, enabled: false)],
    );
    await sender.started.future;
    final stale = track.setPublishingLayersForSender(
      sender,
      sender.parameters.encodings!,
      [lk_rtc.SubscribedQuality(quality: lk_models.VideoQuality.HIGH, enabled: true)],
    );
    track.invalidateSenderParameterOperations();
    sender.release.complete();
    await Future.wait([first, stale]);

    expect(sender.writes, 1);
    expect(sender.parameters.encodings!.single.active, isFalse);
  });
}
