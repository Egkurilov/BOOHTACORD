import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import '../../../services/native_noise_suppression.dart';
import '../audio_profile/profile.dart';
import 'model.dart';
import 'stats.dart';
class VoiceAudioCollector {
  VoiceAudioCollector({this.captureProbe});
  final NativeNoiseSuppression? captureProbe;
  final _reader = AudioStatsReader();
  final _clock = Stopwatch()..start();
  final _identities = Expando<({Object endpoint, String scope})>();
  int _sequence = 0;
  Future<VoiceAudioDiagnostics> read(Room room) async {
    final scopes = <String>{};
    final samples = <Map<String, Object?>>[];
    Future<void> readTrack(rtc.MediaStreamTrack track, Object? endpoint, String direction, Future<List<rtc.StatsReport>> Function() getStats) async {
      if (endpoint == null) return;
      var identity = _identities[track];
      if (identity == null || !identical(identity.endpoint, endpoint)) {
        identity = (endpoint: endpoint, scope: '${++_sequence}');
        _identities[track] = identity;
      }
      scopes.add(identity.scope);
      try {
        final reports = await getStats().timeout(const Duration(milliseconds: 1500));
        samples.addAll(_reader.read(identity.scope, direction, reports.map((report) => <String, Object?>{
          ...report.values, 'id': report.id, 'type': report.type, 'timestamp': report.timestamp,
        }).toList(), _clock.elapsedMicroseconds / 1000));
      } catch (_) { /* Missing native stats stay unknown. */ }
    }
    final local = room.localParticipant?.getTrackPublicationBySource(TrackSource.microphone)?.track;
    final futures = <Future<void>>[];
    if (local is LocalAudioTrack && local.sender != null) {
      futures.add(readTrack(local.mediaStreamTrack, local.sender, 'sender', local.sender!.getStats));
    }
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        final track = publication.track;
        if (publication.source == TrackSource.microphone && publication.subscribed && track is RemoteAudioTrack && track.receiver != null) {
          futures.add(readTrack(track.mediaStreamTrack, track.receiver, 'receiver', track.receiver!.getStats));
        }
      }
    }
    await Future.wait(futures);
    _reader.retain(scopes);
    int? processingRate, processingChannels;
    if (local is LocalAudioTrack) {
      try {
        await captureProbe?.refresh();
        final state = captureProbe?.state;
        if ((state?.sampleRate ?? 0) > 0 && (state?.channels ?? 0) > 0) {
          processingRate = state!.sampleRate;
          processingChannels = state.channels;
        }
      } catch (_) { /* This hook is unavailable on some builds. */ }
    }
    // Native getSettings can echo requested constraints. Do not label those actual.
    final bitrate = room.roomOptions.defaultAudioPublishOptions.encoding?.maxBitrate;
    return VoiceAudioDiagnostics(profileIdForBitrate(bitrate), bitrate, {
      'sampleRate': null, 'channels': null, 'agc': null, 'aec': null, 'ns': null,
      'source': 'unavailable',
      'processingSampleRate': processingRate, 'processingChannels': processingChannels,
    }, samples);
  }
}
