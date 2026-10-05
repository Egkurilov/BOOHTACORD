import 'dart:async';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/audio_device_check.dart';
import 'package:boohtacord_desktop/src/widgets/audio_device_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Publication implements LocalTrackPublication<LocalAudioTrack> {
  _Publication(this.track);
  @override
  final LocalAudioTrack track;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sender implements rtc.RTCRtpSender {
  final enabledAtReplacement = <bool>[];
  @override
  Future<void> replaceTrack(rtc.MediaStreamTrack? track) async {
    enabledAtReplacement.add(track!.enabled);
  }

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

class _Participant implements LocalParticipant {
  _Participant(this.publication);
  final _Publication publication;
  @override
  LocalTrackPublication? getTrackPublicationBySource(TrackSource source) =>
      publication;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Room implements Room {
  _Room(LocalAudioTrack track)
    : localParticipant = _Participant(_Publication(track));
  @override
  final LocalParticipant localParticipant;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Probe implements AudioDeviceCheckService {
  final levels = StreamController<double>.broadcast();
  String? inputId;
  @override
  Future<Stream<double>> startMicrophone({
    String? deviceId,
    String? deviceLabel,
  }) async {
    inputId = deviceId;
    return levels.stream;
  }

  @override
  Future<void> stopMicrophone() async {}
  @override
  Future<void> playSpeaker({String? deviceId, String? deviceLabel}) async {}
  @override
  Future<void> dispose() async {
    await levels.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captures = <Object?>[];
  var captureFailures = 0;
  Completer<void>? captureGate;
  Completer<void>? captureStarted;
  Completer<void>? outputGate;
  Completer<void>? outputStarted;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    captures.clear();
    captureFailures = 0;
    captureGate = null;
    captureStarted = null;
    outputGate = null;
    outputStarted = null;
    SharedPreferences.setMockInitialValues({});
    for (final channel in [
      'FlutterWebRTC.Event',
      'FlutterWebRTC.Logs',
      'livekit_client',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('FlutterWebRTC.Method'),
      (call) async {
        if (call.method == 'getSources') return {'sources': []};
        if (call.method == 'getUserMedia') {
          captures.add(call.arguments);
          final started = captureStarted;
          if (started != null && !started.isCompleted) started.complete();
          final gate = captureGate;
          if (gate != null) await gate.future;
          if (captureFailures > 0) {
            captureFailures--;
            throw PlatformException(code: 'device-unavailable');
          }
          return {
            'streamId': 'capture-${captures.length}',
            'audioTracks': [
              {
                'id': 'mic-${captures.length}',
                'label': 'Synthetic',
                'kind': 'audio',
                'enabled': true,
              },
            ],
            'videoTracks': [],
          };
        }
        if (call.method == 'selectAudioOutput') {
          final started = outputStarted;
          if (started != null && !started.isCompleted) started.complete();
          await outputGate?.future;
        }
        return null;
      },
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      'selection persists and drives capture before any probe on $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          final preferences = await AudioPreferences.open('account-a');
          final owner = AudioDeviceController(readRoom: () => null)
            ..preferences = preferences;
          addTearDown(owner.dispose);
          owner.applyAudioDevices(const [
            MediaDevice('mic-1', 'First', 'audioinput', 'qa'),
            MediaDevice('mic-2', 'Second', 'audioinput', 'qa'),
          ]);
          await owner.selectAudioInput('mic-2');
          expect(owner.audioSettingsError, isNull);
          expect(owner.captureOptions.deviceId, 'mic-2');
          expect(
            (await AudioPreferences.open('account-a')).inputDeviceId,
            'mic-2',
          );
          expect(
            (await AudioPreferences.open('account-b')).inputDeviceId,
            isNull,
          );
          expect(captures, isEmpty);
          final probe = _Probe();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AudioDeviceCheck(
                  inputDeviceId: owner.selectedAudioInputId,
                  inputDeviceLabel: 'Second',
                  outputDeviceId: null,
                  outputDeviceLabel: null,
                  serviceFactory: () => probe,
                ),
              ),
            ),
          );
          await tester.tap(find.text('Проверить микрофон'));
          await tester.pumpAndSettle();
          expect(probe.inputId, 'mic-2');
          expect(owner.captureOptions.deviceId, 'mic-2');
          expect(captures, isEmpty);
          expect(preferences.inputDeviceId, 'mic-2');
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
  for (final muted in [true, false]) {
    testWidgets(
      'active track switches without a probe and preserves mute=$muted',
      (tester) async {
        final track = await LocalAudioTrack.create();
        await track.start();
      final sender = _Sender();
        track.transceiver = _Transceiver(sender);
        addTearDown(track.dispose);
        final room = _Room(track);
        final preferences = await AudioPreferences.open('account-a');
        final owner = AudioDeviceController(readRoom: () => room)
          ..preferences = preferences;
        addTearDown(owner.dispose);
        owner.applyAudioDevices(const [
          MediaDevice('mic-2', 'Second', 'audioinput', 'qa'),
        ]);
        owner.microphoneMutedIntent = muted;
        if (muted) await track.mute(stopOnMute: false);
        await owner.selectAudioInput('mic-2');
        expect(captures, hasLength(2));
        expect(owner.captureOptions.deviceId, 'mic-2');
        expect(track.muted, muted);
        expect(track.mediaStreamTrack.enabled, !muted);
        expect(sender.enabledAtReplacement, [false]);
        final probe = _Probe();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AudioDeviceCheck(
                inputDeviceId: owner.selectedAudioInputId,
                inputDeviceLabel: 'Second',
                outputDeviceId: null,
                outputDeviceLabel: null,
                serviceFactory: () => probe,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Проверить микрофон'));
        await tester.pumpAndSettle();
        expect(captures, hasLength(2));
        expect(track.muted, muted);
        expect(track.currentOptions.deviceId, 'mic-2');
        expect(preferences.inputDeviceId, 'mic-2');
        await tester.pumpWidget(const SizedBox.shrink());
        await track.stop();
      },
    );
  }

  test(
    'active input switch exposes busy state and ignores duplicate changes',
    () async {
      final track = await LocalAudioTrack.create(
        const AudioCaptureOptions(deviceId: 'mic-1'),
      );
      await track.start();
      track.transceiver = _Transceiver(_Sender());
      addTearDown(track.dispose);
      final room = _Room(track);
      final preferences = await AudioPreferences.open('account-a');
      final owner = AudioDeviceController(readRoom: () => room)
        ..preferences = preferences
        ..selectedAudioInputId = 'mic-1'
        ..microphoneMutedIntent = true;
      addTearDown(owner.dispose);
      owner.applyAudioDevices(const [
        MediaDevice('mic-1', 'First', 'audioinput', 'qa'),
        MediaDevice('mic-2', 'Second', 'audioinput', 'qa'),
      ]);
      await track.mute(stopOnMute: false);

      final gate = Completer<void>();
      final started = Completer<void>();
      captureGate = gate;
      captureStarted = started;
      final switching = owner.selectAudioInput('mic-2');
      expect(owner.audioInputSwitching, isTrue);
      expect(owner.selectedAudioInputId, 'mic-1');

      final capturesBeforeSwitch = captures.length;
      await owner.selectAudioInput('mic-1');
      expect(owner.audioInputSwitching, isTrue);
      expect(captures, hasLength(capturesBeforeSwitch));
      await started.future;
      expect(captures, hasLength(capturesBeforeSwitch + 1));

      gate.complete();
      await switching;
      expect(owner.audioInputSwitching, isFalse);
      expect(owner.selectedAudioInputId, 'mic-2');
      expect(owner.audioSettingsError, isNull);
      captureGate = null;
      captureStarted = null;
      await track.stop();
    },
  );

  test(
    'output switch exposes busy state and ignores duplicate changes',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final gate = Completer<void>();
      final started = Completer<void>();
      outputGate = gate;
      outputStarted = started;
      final preferences = await AudioPreferences.open('account-a');
      final owner = AudioDeviceController(readRoom: () => null)
        ..preferences = preferences
        ..selectedAudioOutputId = 'output-1';
      addTearDown(owner.dispose);
      owner.applyAudioDevices(const [
        MediaDevice('output-1', 'First output', 'audiooutput', 'qa'),
        MediaDevice('output-2', 'Second output', 'audiooutput', 'qa'),
      ]);

      final switching = owner.selectAudioOutput('output-2');
      expect(owner.audioOutputSwitching, isTrue);
      await started.future;
      await owner.selectAudioOutput('output-1');
      expect(owner.audioOutputSwitching, isTrue);
      expect(owner.selectedAudioOutputId, 'output-1');

      gate.complete();
      await switching;
      expect(owner.audioOutputSwitching, isFalse);
      expect(owner.audioSettingsError, isNull);
      expect(owner.selectedAudioOutputId, 'output-2');
      outputGate = null;
      outputStarted = null;
    },
  );

  test(
    'failed output switch restores selection and clears busy state',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final gate = Completer<void>();
      final started = Completer<void>();
      outputGate = gate;
      outputStarted = started;
      final preferences = await AudioPreferences.open('account-a');
      final owner = AudioDeviceController(readRoom: () => null)
        ..preferences = preferences
        ..selectedAudioOutputId = 'output-1';
      addTearDown(owner.dispose);
      owner.applyAudioDevices(const [
        MediaDevice('output-1', 'First output', 'audiooutput', 'qa'),
        MediaDevice('output-2', 'Second output', 'audiooutput', 'qa'),
      ]);

      final switching = owner.selectAudioOutput('output-2');
      await started.future;
      expect(owner.audioOutputSwitching, isTrue);
      gate.completeError(StateError('device unavailable'));
      await switching;

      expect(owner.audioOutputSwitching, isFalse);
      expect(owner.selectedAudioOutputId, 'output-1');
      expect(
        owner.audioSettingsError,
        contains('Не удалось переключить динамик'),
      );
      outputGate = null;
      outputStarted = null;
    },
  );

  for (final terminal in [false, true]) {
    testWidgets(
      'failed active selection rolls back or remains muted (terminal=$terminal)',
      (tester) async {
        final track = await LocalAudioTrack.create(
          const AudioCaptureOptions(deviceId: 'mic-1'),
        );
        await track.start();
        track.transceiver = _Transceiver(_Sender());
        addTearDown(track.dispose);
        final room = _Room(track);
        final preferences = await AudioPreferences.open('account-a');
        await preferences.setInputDevice('mic-1');
        final owner = AudioDeviceController(readRoom: () => room)
          ..preferences = preferences
          ..selectedAudioInputId = 'mic-1'
          ..microphoneMutedIntent = false;
        addTearDown(owner.dispose);
        owner.applyAudioDevices(const [
          MediaDevice('mic-2', 'Second', 'audioinput', 'qa'),
        ]);
        owner.selectedAudioInputId = 'mic-1';
        captureFailures = terminal ? 2 : 1;
        await owner.selectAudioInput('mic-2');
        expect(owner.audioSettingsError, isNotNull);
        expect(owner.audioInputSwitching, isFalse);
        expect(owner.selectedAudioInputId, 'mic-1');
        expect(preferences.inputDeviceId, 'mic-1');
        expect(track.muted, terminal);
        expect(track.mediaStreamTrack.enabled, !terminal);
        expect(owner.microphoneMutedIntent, terminal);
        if (terminal) expect(owner.nativeNoise.state.status, 'error');
        await track.stop();
      },
    );
  }
}
