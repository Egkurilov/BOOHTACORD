// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_client/src/proto/livekit_models.pb.dart' as lk;

import 'package:boohtacord_desktop/src/features/voice/screen_viewer/audio_publication.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses an explicit screen-share audio publication', () async {
    final room = _AudioPublicationRoom();
    final created = await RemoteParticipant.createFromInfo(
      room: room,
      info: _participantInfo([
        _track('screen-video', lk.TrackType.VIDEO, lk.TrackSource.SCREEN_SHARE),
        _track('microphone', lk.TrackType.AUDIO, lk.TrackSource.MICROPHONE),
        _track(
          'screen-audio',
          lk.TrackType.AUDIO,
          lk.TrackSource.SCREEN_SHARE_AUDIO,
        ),
      ]),
    );

    expect(
      screenShareAudioPublication(created.participant)?.sid,
      'screen-audio',
    );
    await room.dispose();
  });

  test(
    'recognizes a unique unlabelled audio publication beside a screen',
    () async {
      final room = _AudioPublicationRoom();
      final created = await RemoteParticipant.createFromInfo(
        room: room,
        info: _participantInfo([
          _track(
            'screen-video',
            lk.TrackType.VIDEO,
            lk.TrackSource.SCREEN_SHARE,
          ),
          _track('microphone', lk.TrackType.AUDIO, lk.TrackSource.MICROPHONE),
          _track(
            'legacy-screen-audio',
            lk.TrackType.AUDIO,
            lk.TrackSource.UNKNOWN,
          ),
        ]),
      );

      expect(
        screenShareAudioPublication(created.participant)?.sid,
        'legacy-screen-audio',
      );
      await room.dispose();
    },
  );

  test('does not guess when multiple unlabelled audio tracks exist', () async {
    final room = _AudioPublicationRoom();
    final created = await RemoteParticipant.createFromInfo(
      room: room,
      info: _participantInfo([
        _track('screen-video', lk.TrackType.VIDEO, lk.TrackSource.SCREEN_SHARE),
        _track('legacy-audio-a', lk.TrackType.AUDIO, lk.TrackSource.UNKNOWN),
        _track('legacy-audio-b', lk.TrackType.AUDIO, lk.TrackSource.UNKNOWN),
      ]),
    );

    expect(screenShareAudioPublication(created.participant), isNull);
    await room.dispose();
  });

  test(
    'does not classify an unlabelled microphone without screen video',
    () async {
      final room = _AudioPublicationRoom();
      final created = await RemoteParticipant.createFromInfo(
        room: room,
        info: _participantInfo([
          _track(
            'unlabelled-audio',
            lk.TrackType.AUDIO,
            lk.TrackSource.UNKNOWN,
          ),
        ]),
      );

      expect(screenShareAudioPublication(created.participant), isNull);
      await room.dispose();
    },
  );
}

lk.ParticipantInfo _participantInfo(List<lk.TrackInfo> tracks) =>
    lk.ParticipantInfo(
      sid: 'participant-sid',
      identity: 'streamer',
      tracks: tracks,
    );

lk.TrackInfo _track(String sid, lk.TrackType type, lk.TrackSource source) =>
    lk.TrackInfo(sid: sid, type: type, source: source, muted: false);

class _AudioPublicationRoom extends Room {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
