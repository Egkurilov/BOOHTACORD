import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

class FixtureRoom implements Room {
  FixtureParticipant participant = FixtureParticipant();
  @override
  LocalParticipant get localParticipant => participant;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureParticipant implements LocalParticipant {
  List<LocalTrackPublication<LocalVideoTrack>> publications = [];
  @override
  List<LocalTrackPublication<LocalVideoTrack>> get videoTrackPublications =>
      publications;
  @override
  ConnectionQuality get connectionQuality => ConnectionQuality.excellent;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixturePublication implements LocalTrackPublication<LocalVideoTrack> {
  FixturePublication(this.track, this.sid);
  @override
  final LocalVideoTrack track;
  @override
  final String sid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FixtureTrack implements LocalVideoTrack {
  @override
  VideoPublishOptions? lastPublishOptions;
  rtc.RTCRtpSender? rtpSender;
  @override
  rtc.RTCRtpSender? get sender => rtpSender;
  @override
  Future<bool> stop() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
