import 'dart:async';
import 'dart:collection';

import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';

import 'api.dart';

class PendingVoiceRoom with EventsEmittable<RoomEvent> implements Room {
  final connecting = Completer<void>();
  int disconnected = 0;
  bool connectCalled = false;
  @override
  final PendingMicrophone localParticipant = PendingMicrophone();
  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView({});
  @override
  Future<void> connect(
    String url,
    String token, {
    ConnectOptions? connectOptions,
    RoomOptions? roomOptions,
    FastConnectOptions? fastConnectOptions,
  }) {
    connectCalled = true;
    return connecting.future;
  }

  @override
  Future<void> disconnect() async {
    disconnected++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PendingMicrophone implements LocalParticipant {
  @override
  LocalTrackPublication? getTrackPublicationBySource(TrackSource source) =>
      null;
  final enabled = <bool>[];
  final capture = Completer<void>();
  final started = Completer<void>();
  @override
  Future<LocalTrackPublication?> setMicrophoneEnabled(
    bool value, {
    AudioCaptureOptions? audioCaptureOptions,
  }) async {
    enabled.add(value);
    if (value) {
      if (!started.isCompleted) started.complete();
      await capture.future;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class VoiceHarness {
  VoiceHarness() {
    audio = AudioDeviceController(
      readRoom: () => owner.room,
      loader: () async => enumeratedDevices,
    );
    screen = ScreenShareController(
      api,
      scope,
      readRoom: () => owner.room,
      voiceReady: () => true,
    );
    owner = VoiceController(
      api,
      scope,
      audio,
      screen,
      readUser: () => null,
      reportError: (value) => error = value,
      formatError: (value) => value.toString(),
      roomFactory: (_) {
        created++;
        return room;
      },
    );
  }
  final api = DelayedVoiceApi();
  final scope = SessionScope();
  final room = PendingVoiceRoom();
  List<MediaDevice> enumeratedDevices = const [];
  late final AudioDeviceController audio;
  late final ScreenShareController screen;
  late final VoiceController owner;
  int created = 0;
  String? error;
  Future<void> dispose() async {
    owner.dispose();
    screen.dispose();
    audio.dispose();
    await room.events.dispose();
  }
}
