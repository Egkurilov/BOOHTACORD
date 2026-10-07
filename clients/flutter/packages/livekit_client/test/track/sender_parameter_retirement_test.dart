import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/src/proto/livekit_rtc.pb.dart' as lk_rtc;
import 'package:livekit_client/src/proto/livekit_models.pb.dart' as lk_models;
import 'package:livekit_client/src/options.dart';
import 'package:livekit_client/src/track/local/video.dart';

import '../mock/video_sender.dart';

void main() {
  test('retired sender rejects writers across the unpublish barrier', () async {
    final oldSender = TestVideoSender([rtc.RTCRtpEncoding(rid: 'f')]);
    final track = testScreenTrack(oldSender);
    track.invalidateSenderParameterOperations();
    await track.waitForSenderParameterOperations();

    // This is the interval after the drain barrier and before removeTrack.
    final duringRemoval = track.setPublishingLayersForSender(
      oldSender,
      oldSender.parameters.encodings!,
      [lk_rtc.SubscribedQuality(quality: lk_models.VideoQuality.HIGH, enabled: false)],
    );
    await duringRemoval;
    expect(oldSender.writes, 0);

    final newSender = TestVideoSender([rtc.RTCRtpEncoding(rid: 'f')]);
    track.transceiver = TestVideoTransceiver(newSender);
    track.resumeSenderParameterOperations();
    final staleCallback = track.setPublishingLayersForSender(
      oldSender,
      oldSender.parameters.encodings!,
      [lk_rtc.SubscribedQuality(quality: lk_models.VideoQuality.HIGH, enabled: false)],
    );
    final currentCallback = track.setPublishingLayersForSender(
      newSender,
      newSender.parameters.encodings!,
      [lk_rtc.SubscribedQuality(quality: lk_models.VideoQuality.HIGH, enabled: false)],
    );
    await newSender.started.future;
    newSender.release.complete();
    await Future.wait([staleCallback, currentCallback]);

    expect(oldSender.writes, 0);
    expect(newSender.writes, 1);
    expect(newSender.parameters.encodings!.single.active, isFalse);
  });

  test('retired sender rejects degradation writer started after the barrier', () async {
    final sender = TestVideoSender([rtc.RTCRtpEncoding(rid: 'f')]);
    final track = testScreenTrack(sender);
    track.invalidateSenderParameterOperations();
    await track.waitForSenderParameterOperations();

    final degradationUpdate = track.setDegradationPreference(
      DegradationPreference.maintainResolution,
    );
    sender.release.complete();
    await degradationUpdate;

    expect(sender.writes, 0);
  });
}
