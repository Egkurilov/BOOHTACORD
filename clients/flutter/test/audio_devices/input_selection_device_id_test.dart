import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

class _Publication implements LocalTrackPublication<LocalAudioTrack> {
  _Publication(this.track);
  @override
  final LocalAudioTrack track;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Participant implements LocalParticipant {
  _Participant(this.track);
  final LocalAudioTrack track;
  @override
  LocalTrackPublication? getTrackPublicationBySource(TrackSource source) =>
      _Publication(track);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Room implements Room {
  _Room(this.localParticipant);
  @override
  final LocalParticipant localParticipant;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sender implements rtc.RTCRtpSender {
  @override
  Future<void> replaceTrack(rtc.MediaStreamTrack? track) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transceiver implements rtc.RTCRtpTransceiver {
  _Transceiver(this.sender);
  @override
  final rtc.RTCRtpSender sender;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    for (final channel in [
      'FlutterWebRTC.Event',
      'FlutterWebRTC.Logs',
      'livekit_client',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('FlutterWebRTC.Method'),
      (call) async => call.method == 'getUserMedia'
          ? {
              'streamId': 'capture',
              'audioTracks': [
                {'id': 'mic-capture', 'label': 'Synthetic', 'kind': 'audio', 'enabled': true},
              ],
              'videoTracks': [],
            }
          : null,
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(const MethodChannel('FlutterWebRTC.Method'), null);
  });

  test('empty default alias recaptures the canonical inventory device ID', () async {
    final track = await LocalAudioTrack.create(
      const AudioCaptureOptions(deviceId: 'mic-1'),
    );
    await track.start();
    track.transceiver = _Transceiver(_Sender());
    addTearDown(track.dispose);
    final room = _Room(_Participant(track));
    final owner = AudioDeviceController(readRoom: () => room)
      ..microphoneMutedIntent = true;
    addTearDown(owner.dispose);
    owner.applyAudioDevices(const [
      MediaDevice('default', 'System default', 'audioinput', 'qa'),
    ]);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await owner.selectAudioInput('');

    expect(owner.selectedAudioInputId, 'default');
    expect(track.currentOptions.deviceId, 'default');
  });
}
