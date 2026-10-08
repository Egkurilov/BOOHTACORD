import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/state.dart';

void main() {
  test('bootstraps native audio before the first inventory', () async {
    var initialized = false;
    final owner = AudioDeviceController(
      readRoom: () => null,
      nativeBootstrap: () async {
        initialized = true;
      },
      loader: () async {
        expect(initialized, isTrue);
        return const [
          MediaDevice('mac-input', 'Mac microphone', 'audioinput', null),
          MediaDevice('mac-output', 'Mac speakers', 'audiooutput', null),
        ];
      },
    );
    addTearDown(owner.dispose);

    await owner.bootstrap();

    expect(owner.audioInputDevices.single.deviceId, 'mac-input');
    expect(owner.audioOutputDevices.single.deviceId, 'mac-output');
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
  });

  test(
    'concurrent bootstrap requests share native initialization and scan',
    () async {
      final nativeReady = Completer<void>();
      var nativeCalls = 0;
      var scanCalls = 0;
      final owner = AudioDeviceController(
        readRoom: () => null,
        nativeBootstrap: () {
          nativeCalls++;
          return nativeReady.future;
        },
        loader: () async {
          scanCalls++;
          return const [
            MediaDevice('mac-input', 'Mac microphone', 'audioinput', null),
          ];
        },
      );
      addTearDown(owner.dispose);

      final first = owner.bootstrap();
      final second = owner.bootstrap();
      expect(nativeCalls, 1);
      nativeReady.complete();
      await Future.wait([first, second]);

      expect(scanCalls, 1);
      expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
    },
  );

  test('keeps the inventory available when native bootstrap fails', () async {
    final owner = AudioDeviceController(
      readRoom: () => null,
      nativeBootstrap: () async {
        throw StateError('audio permission is pending');
      },
      loader: () async => const [
        MediaDevice('mac-input', 'Mac microphone', 'audioinput', null),
      ],
    );
    addTearDown(owner.dispose);

    await owner.bootstrap();

    expect(owner.audioInputDevices.single.deviceId, 'mac-input');
    expect(owner.audioDeviceScanFailed, isFalse);
    expect(owner.audioDeviceWarning, contains('аудиосистему'));
  });

  test(
    'permission bootstrap failure is distinct from an enumeration failure',
    () async {
      final owner = AudioDeviceController(
        readRoom: () => null,
        nativeBootstrap: () =>
            Future<void>.error(PlatformException(code: 'permissionDenied')),
        loader: () async => const <MediaDevice>[],
      );
      addTearDown(owner.dispose);

      await owner.bootstrap();

      expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.error);
      expect(
        owner.audioDeviceScanFailure,
        AudioDeviceScanFailure.permissionDenied,
      );
      expect(owner.audioSettingsError, contains('запретил доступ'));
    },
  );

  test('a single real endpoint is a ready inventory, not an error', () async {
    final owner = AudioDeviceController(
      readRoom: () => null,
      loader: () async => const [
        MediaDevice('only-input', 'Only microphone', 'audioinput', null),
      ],
    );
    addTearDown(owner.dispose);

    await owner.refreshAudioDevices();

    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
    expect(owner.audioDeviceScanFailed, isFalse);
  });

  test('an old scan cannot finish a new account scan', () async {
    final scope = SessionScope();
    final old = Completer<List<MediaDevice>>();
    final current = Completer<List<MediaDevice>>();
    var calls = 0;
    final owner = AudioDeviceController(
      scope: scope,
      readRoom: () => null,
      loader: () => calls++ == 0 ? old.future : current.future,
    );
    addTearDown(owner.dispose);
    final oldScan = owner.refreshAudioDevices();
    scope.begin();
    owner.cancelOperations();
    final newScan = owner.refreshAudioDevices();
    old.complete([const MediaDevice('old', 'Old', 'audioinput', 'group')]);
    await oldScan;
    expect(owner.audioDevicesLoading, isTrue);
    expect(owner.audioInputDevices, isEmpty);
    current.complete([const MediaDevice('new', 'New', 'audioinput', 'group')]);
    await newScan;
    expect(owner.audioInputDevices.single.deviceId, 'new');
    expect(owner.audioDevicesLoading, isFalse);
  });

  test(
    'a refresh requested after connect waits for the queued inventory',
    () async {
      final beforeConnect = Completer<List<MediaDevice>>();
      final afterConnect = Completer<List<MediaDevice>>();
      var connected = false;
      var calls = 0;
      final owner = AudioDeviceController(
        readRoom: () => null,
        loader: () {
          calls++;
          return connected ? afterConnect.future : beforeConnect.future;
        },
      );
      addTearDown(owner.dispose);

      final initialRefresh = owner.refreshAudioDevices();
      connected = true;
      var postConnectRefreshCompleted = false;
      final postConnectRefresh = owner.refreshAfterInvalidation().then((_) {
        postConnectRefreshCompleted = true;
      });

      expect(calls, 1);
      expect(postConnectRefreshCompleted, isFalse);
      beforeConnect.complete(const [
        MediaDevice('system-input', 'System microphone', 'audioinput', null),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2);
      expect(postConnectRefreshCompleted, isFalse);
      expect(owner.audioInputDevices.single.deviceId, 'system-input');
      afterConnect.complete(const [
        MediaDevice('usb-input', 'USB microphone', 'audioinput', null),
      ]);
      await Future.wait([initialRefresh, postConnectRefresh]);

      expect(postConnectRefreshCompleted, isTrue);
      expect(owner.audioInputDevices.single.deviceId, 'usb-input');
      expect(owner.audioDevicesLoading, isFalse);
    },
  );

  test('disposing during a queued refresh releases its waiter', () async {
    final loading = Completer<List<MediaDevice>>();
    final owner = AudioDeviceController(
      readRoom: () => null,
      loader: () => loading.future,
    );

    final initialRefresh = owner.refreshAudioDevices();
    var queuedRefreshCompleted = false;
    final queuedRefresh = owner.refreshAfterInvalidation().then((_) {
      queuedRefreshCompleted = true;
    });

    owner.dispose();
    await queuedRefresh;
    expect(queuedRefreshCompleted, isTrue);

    loading.complete(const []);
    await initialRefresh;
  });
}
