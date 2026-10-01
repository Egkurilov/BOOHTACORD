import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  const textChannel = GuildChannel(
    id: 'channel-1',
    name: 'общий',
    kind: ChannelKind.text,
    admissionClosed: false,
  );
  const topology = ChannelTopology(
    revision: 1,
    categories: [
      ChannelCategory(
        id: 'category-1',
        name: 'Текстовые каналы',
        channels: [textChannel],
      ),
    ],
  );

  test('restores a session and selects the first text channel', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);

    await state.initialize();

    expect(state.phase, AppPhase.ready);
    expect(state.user?.accountId, 'account-1');
    expect(state.selectedChannel?.id, textChannel.id);
    expect(state.messages, hasLength(1));
  });

  test(
    'voice roster stream retries after 503 and clears error on snapshot',
    () async {
      final api = _RecoveringRosterApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);
      final errorShown = Completer<void>();
      final rosterRecovered = Completer<void>();
      state.addListener(() {
        if (state.voiceRosterError != null && !errorShown.isCompleted) {
          errorShown.complete();
        }
        if (state.voiceRosters != null && !rosterRecovered.isCompleted) {
          rosterRecovered.complete();
        }
      });

      await state.initialize();
      expect(api.rosterAttempts, 1);
      expect(state.phase, AppPhase.ready);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(state.voiceRosterError, isNotNull);
      await errorShown.future.timeout(const Duration(seconds: 2));
      expect(state.voiceRosters, isNull);

      await rosterRecovered.future.timeout(const Duration(seconds: 4));
      expect(api.rosterAttempts, greaterThanOrEqualTo(2));
      expect(state.voiceRosterError, isNull);
      expect(state.voiceRosters, hasLength(1));
      expect(state.voiceRosters!.single.channelId, 'voice-channel');
      expect(state.voiceRosters!.single.participants, isEmpty);
    },
  );

  test(
    'voice roster snapshot expires 10 seconds after SSE disconnect',
    () async {
      final api = _StaleRosterApi(topology);
      final state = AppState(
        api,
        voiceRosterRetryDelay: const Duration(milliseconds: 1),
        voiceRosterStaleTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(state.dispose);
      final snapshotSeen = Completer<void>();
      final rosterExpired = Completer<void>();
      state.addListener(() {
        if (state.voiceRosters != null && !snapshotSeen.isCompleted) {
          snapshotSeen.complete();
        }
        if (state.voiceRosterError != null && !rosterExpired.isCompleted) {
          rosterExpired.complete();
        }
      });

      await state.initialize();
      await snapshotSeen.future.timeout(const Duration(seconds: 2));
      expect(state.voiceRosters, hasLength(1));

      await rosterExpired.future.timeout(const Duration(seconds: 2));
      expect(state.voiceRosters, isNull);
      expect(state.voiceRosterError, isNotNull);
      expect(api.rosterAttempts, greaterThanOrEqualTo(2));
    },
  );

  test('a recovered roster snapshot cancels its stale timer', () async {
    final api = _RosterStreamRecoversBeforeStaleTimeout(topology);
    final state = AppState(
      api,
      voiceRosterRetryDelay: const Duration(milliseconds: 1),
      voiceRosterStaleTimeout: const Duration(milliseconds: 100),
    );
    addTearDown(state.dispose);

    await state.initialize();
    await api.recovered.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(state.voiceRosters, hasLength(1));
    expect(state.voiceRosterError, isNull);
  });

  testWidgets('a temporary TLS failure offers retry without showing login', (
    tester,
  ) async {
    final api = _FakeApi(topology)
      ..sessionFailure = const HandshakeException('temporary TLS failure');
    final state = AppState(api);

    await state.initialize();
    expect(state.phase, AppPhase.connectionError);
    await tester.pumpWidget(BoohtacordApp(state: state));
    expect(find.text('Повторить подключение'), findsOneWidget);
    expect(find.text('Войти'), findsNothing);

    api.sessionFailure = null;
    await tester.tap(find.text('Повторить подключение'));
    await tester.pumpAndSettle();
    expect(state.phase, AppPhase.ready);
    expect(state.user?.accountId, 'account-1');
    state.dispose();
  });

  testWidgets(
    'a stalled session check exits loading and offers a retryable error',
    (tester) async {
      final api = _FakeApi(topology)..sessionGate = Completer<SessionUser?>();
      final state = AppState(
        api,
        startupSessionTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(state.dispose);

      await tester.runAsync(state.initialize);

      expect(state.phase, AppPhase.connectionError);
      expect(state.error, contains('Проверка сессии не завершилась'));
      await tester.pumpWidget(BoohtacordApp(state: state));
      expect(
        find.textContaining('Проверка сессии не завершилась'),
        findsOneWidget,
      );
      expect(find.text('Повторить подключение'), findsOneWidget);
    },
  );

  test('keeps profile load errors separate and clears them on retry', () async {
    final api = _FakeApi(topology)
      ..profileFailure = const ApiFailure('Профиль временно недоступен.');
    final state = AppState(api);
    addTearDown(state.dispose);

    await state.refreshProfile();

    expect(state.profile, isNull);
    expect(state.profileLoading, isFalse);
    expect(state.profileLoadError, 'Профиль временно недоступен.');
    expect(state.error, isNull);

    api.profileFailure = null;
    await state.refreshProfile();

    expect(state.profileLoadError, isNull);
    expect(state.profile?.displayName, 'Участник');
    expect(state.profileLoading, isFalse);
  });

  test(
    'profile display name validation matches web code points exactly',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);

      const displayName = '  😀  ';
      expect(await state.saveDisplayName(displayName), isTrue);
      expect(api.updatedDisplayName, displayName);

      final tooLong = List.filled(65, '😀').join();
      expect(await state.saveDisplayName(tooLong), isFalse);
      expect(api.updatedDisplayName, displayName);
      expect(state.error, 'Имя должно содержать от 1 до 64 символов.');
    },
  );

  test(
    'profile password validation matches web 12–128 code point limits',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);
      final valid = List.filled(12, '😀').join();
      final tooLong = List.filled(129, '😀').join();

      expect(await state.updatePassword(tooLong, valid), isFalse);
      expect(await state.updatePassword(valid, tooLong), isFalse);
      expect(api.passwordChangeRequests, 0);

      expect(await state.updatePassword(valid, valid), isTrue);
      expect(api.passwordChangeRequests, 1);
    },
  );

  test(
    'clears the selected channel when refreshed topology archives it',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();
      expect(state.selectedChannel?.id, textChannel.id);

      api.value = const ChannelTopology(revision: 2, categories: []);
      await state.refreshTopology();

      expect(state.topology?.revision, 2);
      expect(state.selectedChannel, isNull);
      expect(state.messages, isEmpty);
      expect(state.nextMessageCursor, isNull);
    },
  );

  test('screen sharing requires an active voice connection', () async {
    final state = AppState(_FakeApi(topology));
    addTearDown(state.dispose);

    await state.startScreenShare();

    expect(state.screenSharePhase, ScreenSharePhase.error);
    expect(
      state.screenShareError,
      'Подключитесь к голосовому каналу перед демонстрацией.',
    );
  });

  test('screen-share errors keep the native failure detail', () {
    expect(
      screenShareFailureDetail('permission was denied'),
      'permission was denied',
    );
    expect(
      screenShareFailureDetail(StateError('capture service unavailable')),
      'capture service unavailable',
    );
    expect(
      screenShareFailureDetail(
        PlatformException(
          code: 'Capture Failed',
          message: 'Не удалось запустить захват выбранного источника.',
        ),
      ),
      'Не удалось запустить захват выбранного источника.',
    );
    expect(
      screenShareFailureDetail(Exception('encoder negotiation failed')),
      contains('encoder negotiation failed'),
    );
  });

  test('updates audio devices when a headset is connected', () async {
    final changes = StreamController<List<MediaDevice>>.broadcast();
    final state = AppState(
      _FakeApi(topology),
      audioDeviceLoader: () async => const [
        MediaDevice('built-in', 'Built-in microphone', 'audioinput', null),
      ],
      audioDeviceChanges: changes.stream,
    );
    addTearDown(() async {
      state.dispose();
      await changes.close();
    });
    await state.initialize();
    await state.refreshAudioDevices();
    state.selectedAudioInputId = 'built-in';
    state.toggleWorkspacePanel(WorkspacePanel.audio);

    changes.add(const [
      MediaDevice('usb-mic', 'USB microphone', 'audioinput', null),
      MediaDevice('usb-speaker', 'USB speaker', 'audiooutput', null),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(state.audioInputDevices.single.deviceId, 'usb-mic');
    expect(state.audioOutputDevices.single.deviceId, 'usb-speaker');
    expect(state.selectedAudioInputId, 'usb-mic');
    expect(
      state.audioDeviceWarning,
      'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.',
    );
  });

  test(
    'warns and selects an available device when the chosen mic is disconnected',
    () async {
      SharedPreferences.setMockInitialValues({});
      var available = const [
        MediaDevice('mic-old', 'USB microphone', 'audioinput', null),
        MediaDevice('speaker', 'Speakers', 'audiooutput', null),
      ];
      final state = AppState(
        _FakeApi(topology),
        audioDeviceLoader: () async => available,
      );
      addTearDown(state.dispose);
      await state.initialize();
      await state.refreshAudioDevices();
      state.selectedAudioInputId = 'mic-old';
      state.selectedAudioOutputId = 'speaker';

      available = const [];
      await state.refreshAudioDevices();

      expect(state.selectedAudioInputId, 'mic-old');
      expect(state.selectedAudioOutputId, 'speaker');
      expect(state.audioDeviceWarning, isNull);

      available = const [
        MediaDevice('mic-new', 'Built-in microphone', 'audioinput', null),
        MediaDevice('speaker', 'Speakers', 'audiooutput', null),
      ];
      await state.refreshAudioDevices();

      expect(state.selectedAudioInputId, 'mic-new');
      expect(state.selectedAudioOutputId, 'speaker');
      expect(
        state.audioDeviceWarning,
        'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.',
      );
    },
  );

  test(
    'retains Android USB routes after a WebRTC device-change event',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const audioChannel = MethodChannel('boohtacord/audio_devices');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(audioChannel, (call) async {
            if (call.method == 'enumerateAudioDevices') {
              return [
                {
                  'deviceId': '41',
                  'kind': 'audioinput',
                  'label': 'USB microphone',
                  'groupId': 'usb:41',
                },
                {
                  'deviceId': 'android-usb-route:42',
                  'kind': 'audiooutput',
                  'label': 'USB headset',
                  'groupId': 'usb:42',
                },
              ];
            }
            return null;
          });
      final changes = StreamController<List<MediaDevice>>.broadcast();
      final state = AppState(
        _FakeApi(topology),
        audioDeviceLoader: () async => const [],
        audioDeviceChanges: changes.stream,
      );
      addTearDown(() async {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(audioChannel, null);
        state.dispose();
        await changes.close();
      });
      await state.initialize();
      state.toggleWorkspacePanel(WorkspacePanel.audio);

      changes.add(const [
        MediaDevice('default-mic', 'Microphone', 'audioinput', null),
        MediaDevice('default-speaker', 'Speaker', 'audiooutput', null),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        state.audioInputDevices.map((device) => device.deviceId),
        contains('41'),
      );
      expect(
        state.audioOutputDevices.map((device) => device.deviceId),
        contains('android-usb-route:42'),
      );
    },
  );

  test(
    'keeps Android system output available after an empty device-change scan',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const audioChannel = MethodChannel('boohtacord/audio_devices');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(audioChannel, (call) async {
            if (call.method == 'enumerateAudioDevices') return const [];
            return null;
          });
      final changes = StreamController<List<MediaDevice>>.broadcast();
      final state = AppState(
        _FakeApi(topology),
        audioDeviceLoader: () async => const [],
        audioDeviceChanges: changes.stream,
      );
      addTearDown(() async {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(audioChannel, null);
        state.dispose();
        await changes.close();
      });
      await state.initialize();
      state.toggleWorkspacePanel(WorkspacePanel.audio);

      changes.add(const [
        MediaDevice('built-in-mic', 'Built-in microphone', 'audioinput', null),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        state.audioOutputDevices,
        contains(
          const MediaDevice(
            'default',
            'Системный динамик',
            'audiooutput',
            'android:default',
          ),
        ),
      );
    },
  );

  test('does not replace a hotplug event with a stale device scan', () async {
    final changes = StreamController<List<MediaDevice>>.broadcast();
    final oldScan = Completer<List<MediaDevice>>();
    final state = AppState(
      _FakeApi(topology),
      audioDeviceLoader: () => oldScan.future,
      audioDeviceChanges: changes.stream,
    );
    addTearDown(() async {
      state.dispose();
      await changes.close();
    });
    await state.initialize();
    state.toggleWorkspacePanel(WorkspacePanel.audio);
    changes.add(const [
      MediaDevice('usb-mic', 'USB microphone', 'audioinput', null),
    ]);
    await Future<void>.delayed(Duration.zero);
    oldScan.complete(const [
      MediaDevice('built-in', 'Built-in microphone', 'audioinput', null),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(state.audioInputDevices.single.deviceId, 'usb-mic');
    expect(state.audioDevicesLoading, isFalse);
  });

  test(
    'does not show a stale scan error after a newer hotplug event',
    () async {
      final changes = StreamController<List<MediaDevice>>.broadcast();
      final oldScan = Completer<List<MediaDevice>>();
      final state = AppState(
        _FakeApi(topology),
        audioDeviceLoader: () => oldScan.future,
        audioDeviceChanges: changes.stream,
      );
      addTearDown(() async {
        state.dispose();
        await changes.close();
      });
      await state.initialize();
      state.toggleWorkspacePanel(WorkspacePanel.audio);
      changes.add(const [
        MediaDevice('usb-mic', 'USB microphone', 'audioinput', null),
      ]);
      await Future<void>.delayed(Duration.zero);
      oldScan.completeError(StateError('obsolete scan failed'));
      await Future<void>.delayed(Duration.zero);

      expect(state.audioInputDevices.single.deviceId, 'usb-mic');
      expect(state.audioSettingsError, isNull);
      expect(state.audioDeviceScanFailed, isFalse);
      expect(state.audioDevicesLoading, isFalse);
    },
  );

  test(
    'marks a current audio device scan failure separately from empty',
    () async {
      final state = AppState(
        _FakeApi(topology),
        audioDeviceLoader: () async => throw StateError('enumeration failed'),
      );
      addTearDown(state.dispose);
      await state.initialize();

      await state.refreshAudioDevices();

      expect(state.audioDeviceScanFailed, isTrue);
      expect(state.audioSettingsError, contains('Не удалось получить список'));
      expect(state.audioInputDevices, isEmpty);
      expect(state.audioOutputDevices, isEmpty);
    },
  );

  test('queues a device refresh requested during an active scan', () async {
    final firstScan = Completer<List<MediaDevice>>();
    final secondScan = Completer<List<MediaDevice>>();
    var scanCount = 0;
    final state = AppState(
      _FakeApi(topology),
      audioDeviceLoader: () {
        scanCount++;
        return scanCount == 1 ? firstScan.future : secondScan.future;
      },
    );
    addTearDown(state.dispose);
    await state.initialize();

    final initialRefresh = state.refreshAudioDevices();
    await Future<void>.delayed(Duration.zero);
    await state.refreshAudioDevices();
    firstScan.complete(const [
      MediaDevice('default-input', 'System default', 'audioinput', null),
    ]);
    await initialRefresh;
    await Future<void>.delayed(Duration.zero);

    expect(scanCount, 2);
    secondScan.complete(const [
      MediaDevice('usb-input', 'USB microphone', 'audioinput', null),
      MediaDevice('usb-output', 'USB headphones', 'audiooutput', null),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(state.audioInputDevices.single.deviceId, 'usb-input');
    expect(state.audioOutputDevices.single.deviceId, 'usb-output');
    expect(state.audioDevicesLoading, isFalse);
  });

  test(
    'persists PTT mode and refuses to unmute without an active room',
    () async {
      final state = AppState(_FakeApi(topology));
      addTearDown(state.dispose);
      await state.initialize();

      await state.setPushToTalkKey(97, 'A');
      await state.setAudioActivationMode(AudioActivationMode.ptt);
      await state.setPushToTalkPressed(true);

      expect(state.audioActivationMode, AudioActivationMode.ptt);
      expect(state.pushToTalkKeyId, 97);
      expect(state.pushToTalkKeyLabel, 'A');
      expect(state.pushToTalkPressed, isFalse);
      expect(state.microphoneMuted, isFalse);
    },
  );

  test('releases held PTT state when key-up occurs during reconnect', () async {
    final state = AppState(_FakeApi(topology));
    addTearDown(state.dispose);
    await state.initialize();
    state.audioActivationMode = AudioActivationMode.ptt;
    state.voicePhase = VoicePhase.reconnecting;
    state.pushToTalkPressed = true;
    state.microphoneMuted = false;

    await state.setPushToTalkPressed(false);

    expect(state.pushToTalkPressed, isFalse);
    expect(state.microphoneMuted, isTrue);
  });

  test(
    'clears private workspace state when the session is unauthorized',
    () async {
      final state = AppState(_FakeApi(topology));
      addTearDown(state.dispose);
      await state.initialize();

      state.api.onUnauthorized?.call();

      expect(state.phase, AppPhase.signedOut);
      expect(state.user, isNull);
      expect(state.profile, isNull);
      expect(state.topology, isNull);
      expect(state.messages, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(state.error, isNull);
    },
  );

  test(
    'uses reset link once and returns focus to login on completion',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);
      final token = List.filled(43, 'a').join();

      state.openPasswordResetLink(
        'https://v.bootybay.ru/reset-password#token=$token',
      );
      expect(state.resetRoute, isTrue);
      expect(state.resetToken, token);

      expect(await state.completePasswordReset('a long password 123'), isTrue);
      expect(api.passwordResetCompleted, isTrue);
      expect(state.resetToken, isNull);
      expect(state.resetCompleted, isTrue);

      state.returnToLogin();
      expect(state.resetRoute, isFalse);
      expect(state.focusLoginOnMount, isTrue);
    },
  );

  test(
    'advances text read cursor once for the newest visible message',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();

      await state.markTextChannelRead(textChannel.id, state.messages.last.id);
      await state.markTextChannelRead(textChannel.id, state.messages.last.id);

      expect(api.advancedTextChannelId, textChannel.id);
      expect(api.advancedTextMessageId, 'message-1');
      expect(api.textReadAdvances, 1);
    },
  );

  test('adds a server-confirmed message to the conversation', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    final sent = await state.send(
      'Новое сообщение',
      replyToId: 'message-reply-target',
      mentionUserIds: ['account-2', 'account-2'],
      attachments: const [
        MessageAttachment(id: 'file-1', originalName: 'file.txt', sizeBytes: 3),
      ],
    );

    expect(sent, isTrue);
    expect(state.messages.last.body, 'Новое сообщение');
    expect(state.messages.last.replyToId, 'message-reply-target');
    expect(api.sentReplyToId, 'message-reply-target');
    expect(api.sentMentionIds, ['account-2']);
    expect(api.sentAttachmentIds, ['file-1']);
    expect(state.messages.last.attachments.single.id, 'file-1');
    expect(state.sending, isFalse);
  });

  test('reuses the text send ID after an uncertain failure', () async {
    final api = _FakeApi(topology)..failTextSends = 1;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.send('Привет', replyToId: 'message-1'), isFalse);
    final failed = state.messages.last;
    expect(failed.sendStatus, MessageSendStatus.failed);
    expect(failed.clientMessageId, api.textSendIds.single);
    expect(await state.retryTextSend(failed.clientMessageId!), isTrue);
    expect(api.textSendIds[1], api.textSendIds[0]);
    expect(
      state.messages.where((message) => message.body == 'Привет'),
      hasLength(1),
    );

    expect(await state.send('Другой текст'), isTrue);
    expect(api.textSendIds[2], isNot(api.textSendIds[1]));
  });

  test('counts Unicode code points for the message limit', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.send('🙂' * 5000), isTrue);
    expect(state.messages.last.body.runes.length, 5000);
  });

  test('allows attachment-only TEXT messages but rejects a blank draft without files', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.send(''), isFalse);
    expect(api.textSendIds, isEmpty);
    expect(
      await state.send(
        '',
        attachments: const [
          MessageAttachment(
            id: 'file-image',
            originalName: 'clipboard.png',
            sizeBytes: 4,
          ),
        ],
      ),
      isTrue,
    );
    expect(api.sentAttachmentIds, ['file-image']);
    expect(state.messages.last.body, isEmpty);
    expect(state.messages.last.attachments.single.id, 'file-image');
  });

  test('reconciles a lost text acknowledgement with server history', () async {
    final api = _FakeApi(topology)..failTextSends = 1;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.send('Привет'), isFalse);
    expect(state.messages.last.sendStatus, MessageSendStatus.failed);
    api.committedTextClientId = api.textSendIds.single;
    await state.selectChannel(textChannel);
    expect(
      state.messages.where((message) => message.body == 'Привет'),
      hasLength(1),
    );
    expect(state.messages.last.sendStatus, isNull);
    expect(await state.retryTextSend(api.textSendIds.first), isFalse);

    expect(await state.send('Привет'), isTrue);
    expect(api.textSendIds.last, isNot(api.textSendIds.first));
  });

  test('reuses the direct send ID without inserting into another DM', () async {
    final api = _FakeApi(topology, includeDirectMessage: true)
      ..failDirectSends = 1;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    final first = state.directMessages.single;
    await state.openDirectConversation(first);

    expect(await state.sendDirect('Личное приветствие'), isFalse);
    final failedId = state.directMessageHistory.last.clientMessageId!;
    expect(
      state.directMessageHistory.last.sendStatus,
      MessageSendStatus.failed,
    );
    const other = DirectConversation(
      id: 'dm-2',
      participantId: 'account-3',
      displayName: 'Другой собеседник',
      unreadCount: 0,
    );
    await state.openDirectConversation(other);
    expect(await state.sendDirect('Другое сообщение'), isTrue);
    expect(state.directMessageHistory.last.body, 'Другое сообщение');
    await state.openDirectConversation(first);
    expect(
      state.directMessageHistory.last.sendStatus,
      MessageSendStatus.failed,
    );
    expect(await state.retryDirectSend(failedId), isTrue);
    expect(api.directSendIds.last, api.directSendIds.first);
    expect(api.directSendIds[1], isNot(api.directSendIds.first));
  });

  test('allows attachment-only DM messages but rejects an empty draft without files', () async {
    final api = _FakeApi(topology, includeDirectMessage: true);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);

    expect(await state.sendDirect(''), isFalse);
    expect(api.directSendIds, isEmpty);
    expect(
      await state.sendDirect(
        '',
        attachments: const [
          MessageAttachment(
            id: 'dm-file-image',
            originalName: 'clipboard.png',
            sizeBytes: 4,
          ),
        ],
      ),
      isTrue,
    );
    expect(api.sentDirectAttachmentIds, ['dm-file-image']);
    expect(state.directMessageHistory.last.body, isEmpty);
    expect(
      state.directMessageHistory.last.attachments.single.id,
      'dm-file-image',
    );
  });

  test('does not append a delayed text send into the next channel', () async {
    final gate = Completer<void>();
    final api = _FakeApi(topology)..textSendGate = gate;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    final pending = state.send('Сообщение первого канала');
    expect(state.messages.last.sendStatus, MessageSendStatus.sending);
    const other = GuildChannel(
      id: 'channel-2',
      name: 'другой',
      kind: ChannelKind.text,
      admissionClosed: false,
    );
    await state.selectChannel(other);
    gate.complete();
    expect(await pending, isTrue);
    expect(state.selectedChannel?.id, other.id);
    expect(
      state.messages.every((message) => message.channelId == other.id),
      isTrue,
    );
  });

  test(
    'loads older text history by cursor without duplicating messages',
    () async {
      final api = _FakeApi(topology, paginated: true);
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();

      expect(state.nextMessageCursor, 'older-page');
      expect(await state.loadOlderMessages(), isTrue);
      expect(state.messages.map((message) => message.id), [
        'message-older',
        'message-1',
      ]);
      expect(state.nextMessageCursor, isNull);
      expect(api.olderPageRequests, 1);
    },
  );

  test(
    'realtime text refresh preserves already loaded history pages',
    () async {
      final api = _FakeApi(topology, paginated: true);
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();
      await state.loadOlderMessages();
      api.committedTextClientId = 'realtime-client-message';

      await state.refreshSelectedTextHistory();

      expect(state.messages.map((message) => message.id), [
        'message-older',
        'message-1',
        'message-committed',
      ]);
      expect(state.nextMessageCursor, isNull);
    },
  );

  test('requests an existing voice lease transfer immediately', () async {
    final api = _FakeApi(
      topology,
      voiceFailure: const ApiFailure(
        'Голос уже подключён в другом окне',
        status: 409,
        code: 'ACTIVE_VOICE_LEASE',
      ),
      transferFailure: const ApiFailure('Перенос недоступен', status: 503),
    );
    final state = AppState(api);
    addTearDown(state.dispose);
    const voiceChannel = GuildChannel(
      id: 'voice-1',
      name: 'Лобби',
      kind: ChannelKind.voice,
      admissionClosed: false,
    );

    await state.joinVoice(voiceChannel);

    expect(state.voicePhase, VoicePhase.error);
    expect(api.voiceTransferAttempts, [true]);
    expect(state.error, contains('Перенос недоступен'));
  });

  test('reports an unrelated voice admission failure without retry', () async {
    final api = _FakeApi(
      topology,
      transferFailure: const ApiFailure('Вход закрыт', status: 403),
    );
    final state = AppState(api);
    addTearDown(state.dispose);
    const voiceChannel = GuildChannel(
      id: 'voice-1',
      name: 'Лобби',
      kind: ChannelKind.voice,
      admissionClosed: false,
    );

    await state.joinVoice(voiceChannel);

    expect(api.voiceTransferAttempts, [true]);
    expect(state.error, 'Вход закрыт');
  });

  test('loads a direct message and advances cursor after rendering', () async {
    final api = _FakeApi(topology, includeDirectMessage: true);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    await state.showDirectMessages();
    await state.openDirectConversation(state.directMessages.single);
    await state.markSelectedDirectMessageRead();

    expect(state.directMessageHistory.single.body, 'Личное сообщение');
    expect(state.directMessages.single.unreadCount, 0);
    expect(api.advancedMessageId, 'dm-message-1');
    expect(
      await state.sendDirect(
        'Ответ',
        replyToId: 'dm-message-1',
        mentionUserIds: ['account-2'],
        attachments: const [
          MessageAttachment(id: 'file-2', originalName: 'dm.txt', sizeBytes: 4),
        ],
      ),
      isTrue,
    );
    expect(api.sentDirectReplyToId, 'dm-message-1');
    expect(api.sentDirectMentionIds, ['account-2']);
    expect(api.sentDirectAttachmentIds, ['file-2']);
    expect(state.directMessageHistory.last.attachments.single.id, 'file-2');
    expect(state.directMessageHistory.last.replyToId, 'dm-message-1');
  });

  test('edits a text message using its current revision', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();

    final edited = await state.editText(state.messages.single, 'Исправлено');

    expect(edited, isTrue);
    expect(state.messages.single.body, 'Исправлено');
    expect(api.editedRevision, 1);
  });

  test(
    'refreshes a conflicted older text revision without losing history',
    () async {
      final api = _FakeApi(topology, paginated: true)..failTextEdits = 1;
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();
      await state.loadOlderMessages();
      final original = state.messages.first;

      final result = await state.editTextWithResult(
        original,
        'Мой черновик',
        original.revision,
      );
      expect(result.kind, MessageEditStatus.conflict);
      expect(state.messages.map((message) => message.id), [
        'message-older',
        'message-1',
      ]);

      api.olderTextRevision = 2;
      final refreshed = await state.refreshTextMessageRevision(original);
      expect(refreshed?.revision, 2);
      expect(state.messages.map((message) => message.id), [
        'message-older',
        'message-1',
      ]);
      expect(
        (await state.editTextWithResult(original, 'Мой черновик', 2)).kind,
        MessageEditStatus.saved,
      );
      expect(api.editedRevision, 2);
      expect(state.messages.first.body, 'Мой черновик');
    },
  );

  test(
    'refreshes a conflicted older DM revision without losing history',
    () async {
      final api = _FakeApi(
        topology,
        includeDirectMessage: true,
        paginated: true,
      )..failDirectEdits = 1;
      final state = AppState(api);
      addTearDown(state.dispose);
      await state.initialize();
      await state.openDirectConversation(state.directMessages.single);
      await state.loadOlderDirectMessages();
      final original = state.directMessageHistory.first;

      final result = await state.editDirectWithResult(
        original,
        'Мой черновик',
        original.revision,
      );
      expect(result.kind, MessageEditStatus.conflict);
      api.olderDirectRevision = 2;
      final refreshed = await state.refreshDirectMessageRevision(original);
      expect(refreshed?.revision, 2);
      expect(state.directMessageHistory.map((message) => message.id), [
        'dm-message-older',
        'dm-message-1',
      ]);
      expect(
        (await state.editDirectWithResult(original, 'Мой черновик', 2)).kind,
        MessageEditStatus.saved,
      );
      expect(api.editedDirectRevision, 2);
    },
  );

  test('deletes an older text row without discarding loaded pages', () async {
    final api = _FakeApi(topology, paginated: true);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    await state.loadOlderMessages();

    await state.deleteText(state.messages.first);

    expect(api.deletedTextMessageId, 'message-older');
    expect(state.messages.map((message) => message.id), [
      'message-older',
      'message-1',
    ]);
    expect(state.messages.first.deleted, isTrue);
    expect(state.messages.first.body, isEmpty);
    expect(state.messages.first.revision, 2);
    expect(api.olderPageRequests, 1);
  });

  test('deletes an older DM row without discarding loaded pages', () async {
    final api = _FakeApi(topology, includeDirectMessage: true, paginated: true);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    await state.openDirectConversation(state.directMessages.single);
    await state.loadOlderDirectMessages();

    await state.deleteDirect(state.directMessageHistory.first);

    expect(api.deletedDirectMessageId, 'dm-message-older');
    expect(state.directMessageHistory.map((message) => message.id), [
      'dm-message-older',
      'dm-message-1',
    ]);
    expect(state.directMessageHistory.first.deleted, isTrue);
    expect(state.directMessageHistory.first.revision, 2);
  });

  test('does not place a delayed edit into the next channel', () async {
    final gate = Completer<void>();
    final api = _FakeApi(topology)..textEditGate = gate;
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    final pending = state.editTextWithResult(
      state.messages.single,
      'Запоздавший текст',
      1,
    );
    const other = GuildChannel(
      id: 'channel-2',
      name: 'другой',
      kind: ChannelKind.text,
      admissionClosed: false,
    );
    await state.selectChannel(other);
    gate.complete();

    expect((await pending).kind, MessageEditStatus.stale);
    expect(
      state.messages.every((message) => message.channelId == other.id),
      isTrue,
    );
  });

  test('routes attachment bytes to the explicit conversation', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);
    await state.initialize();
    final bytes = Uint8List.fromList([1, 2]);
    const other = GuildChannel(
      id: 'channel-2',
      name: 'другой',
      kind: ChannelKind.text,
      admissionClosed: false,
    );
    await state.selectChannel(other);

    await state.uploadAttachment('text.txt', bytes, channelId: textChannel.id);
    await state.uploadAttachment('dm.txt', bytes, directMessageId: 'dm-1');

    expect(api.uploadedTextChannelId, textChannel.id);
    expect(api.uploadedDirectMessageId, 'dm-1');
  });
}

class _FakeApi extends ApiClient {
  _FakeApi(
    this.value, {
    this.voiceFailure,
    this.transferFailure,
    this.includeDirectMessage = false,
    this.paginated = false,
  });
  ChannelTopology value;
  final ApiFailure? voiceFailure;
  final ApiFailure? transferFailure;
  final List<bool> voiceTransferAttempts = [];
  final bool includeDirectMessage;
  final bool paginated;
  int olderPageRequests = 0;
  String? advancedMessageId;
  String? advancedTextChannelId;
  String? advancedTextMessageId;
  int textReadAdvances = 0;
  int? editedRevision;
  int? editedDirectRevision;
  int failTextEdits = 0;
  int failDirectEdits = 0;
  int olderTextRevision = 1;
  int olderDirectRevision = 1;
  String? deletedTextMessageId;
  String? deletedDirectMessageId;
  String? uploadedTextChannelId;
  String? uploadedDirectMessageId;
  bool passwordResetCompleted = false;
  Object? profileFailure;
  Object? sessionFailure;
  Completer<SessionUser?>? sessionGate;
  String? updatedDisplayName;
  int passwordChangeRequests = 0;
  String? sentReplyToId;
  String? sentDirectReplyToId;
  List<String> sentMentionIds = const [];
  List<String> sentDirectMentionIds = const [];
  List<String> sentAttachmentIds = const [];
  List<String> sentDirectAttachmentIds = const [];
  int failTextSends = 0;
  int failDirectSends = 0;
  String? committedTextClientId;
  Completer<void>? textSendGate;
  Completer<void>? textEditGate;
  final textSendIds = <String>[];
  final directSendIds = <String>[];

  @override
  bool get realtimeEnabled => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> maintenanceActive() async => false;

  @override
  Future<SessionUser?> currentSession() async {
    final failure = sessionFailure;
    if (failure != null) throw failure;
    final gate = sessionGate;
    if (gate != null) return gate.future;
    return const SessionUser(accountId: 'account-1', role: 'MEMBER');
  }

  @override
  Future<OwnProfile> ownProfile() async {
    final failure = profileFailure;
    if (failure != null) throw failure;
    return const OwnProfile(
      accountId: 'account-1',
      login: 'member',
      displayName: 'Участник',
      role: 'MEMBER',
    );
  }

  @override
  Future<OwnProfile> updateOwnProfile(String displayName) async {
    updatedDisplayName = displayName;
    return OwnProfile(
      accountId: 'account-1',
      login: 'member',
      displayName: displayName,
      role: 'MEMBER',
    );
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    passwordChangeRequests++;
  }

  @override
  Future<void> completePasswordReset(String token, String password) async {
    passwordResetCompleted = token.length == 43 && password.isNotEmpty;
  }

  @override
  Future<ChannelTopology> topology() async => value;

  @override
  Future<void> advanceTextChannelReadCursor(
    String channelId,
    String messageId,
  ) async {
    advancedTextChannelId = channelId;
    advancedTextMessageId = messageId;
    textReadAdvances++;
  }

  @override
  Future<List<GuildMember>> members() async => const [];

  @override
  Future<List<DirectConversation>> directMessages() async =>
      includeDirectMessage
      ? const [
          DirectConversation(
            id: 'dm-1',
            participantId: 'account-2',
            displayName: 'Собеседник',
            unreadCount: 1,
          ),
        ]
      : const [];

  @override
  Future<DirectChatMessage> sendDirectMessage(
    String directMessageId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    directSendIds.add(clientMessageId);
    if (failDirectSends > 0) {
      failDirectSends--;
      throw const ApiFailure('Подтверждение отправки потеряно.');
    }
    sentDirectReplyToId = replyToId;
    sentDirectMentionIds = mentionUserIds;
    sentDirectAttachmentIds = attachmentIds;
    return DirectChatMessage(
      id: 'dm-message-${directSendIds.length + 1}',
      directMessageId: directMessageId,
      clientMessageId: clientMessageId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 20, 1),
      deleted: false,
      revision: 1,
      replyToId: replyToId,
      attachments: [
        for (final id in attachmentIds)
          MessageAttachment(id: id, originalName: 'file.txt', sizeBytes: 3),
      ],
    );
  }

  @override
  Future<List<DirectCandidate>> directMessageCandidates() async => const [];

  @override
  Future<List<DirectChatMessage>> directMessageHistory(String id) async => [
    DirectChatMessage(
      id: 'dm-message-1',
      directMessageId: id,
      authorId: 'account-2',
      body: 'Личное сообщение',
      createdAt: DateTime.utc(2026, 9, 24),
      deleted: false,
      revision: 1,
    ),
  ];

  @override
  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,
    String? at,
  }) async => paginated
      ? before != null
            ? DirectChatMessagePage(
                messages: [
                  DirectChatMessage(
                    id: 'dm-message-older',
                    directMessageId: id,
                    authorId: 'account-1',
                    body: 'Старое личное сообщение',
                    createdAt: DateTime.utc(2026, 9, 19),
                    deleted: false,
                    revision: olderDirectRevision,
                  ),
                ],
              )
            : DirectChatMessagePage(
                messages: await directMessageHistory(id),
                nextCursor: 'older-dm-page',
              )
      : DirectChatMessagePage(messages: await directMessageHistory(id));

  @override
  Future<void> advanceDirectMessageReadCursor(
    String directMessageId,
    String messageId,
  ) async {
    advancedMessageId = messageId;
  }

  @override
  Future<List<ChatMessage>> messages(String channelId) async => [
    ChatMessage(
      id: 'message-1',
      channelId: channelId,
      authorId: 'account-1',
      body: 'Первое сообщение',
      createdAt: DateTime.utc(2026, 9, 20),
      deleted: false,
      revision: 1,
    ),
  ];

  @override
  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) async {
    if (paginated && before != null) {
      olderPageRequests++;
      return ChatMessagePage(
        messages: [
          ChatMessage(
            id: 'message-older',
            channelId: channelId,
            authorId: 'account-2',
            body: 'Старое сообщение',
            createdAt: DateTime.utc(2026, 9, 19),
            deleted: false,
            revision: olderTextRevision,
          ),
        ],
      );
    }
    return ChatMessagePage(
      messages: [
        ...await messages(channelId),
        if (committedTextClientId != null)
          ChatMessage(
            id: 'message-committed',
            channelId: channelId,
            authorId: 'account-1',
            clientMessageId: committedTextClientId,
            body: 'Привет',
            createdAt: DateTime.utc(2026, 9, 20, 1),
            deleted: false,
            revision: 1,
          ),
      ],
      nextCursor: paginated ? 'older-page' : null,
    );
  }

  @override
  Future<ChatMessage> sendMessage(
    String channelId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    await textSendGate?.future;
    textSendIds.add(clientMessageId);
    if (failTextSends > 0) {
      failTextSends--;
      throw const ApiFailure('Подтверждение отправки потеряно.');
    }
    sentReplyToId = replyToId;
    sentMentionIds = mentionUserIds;
    sentAttachmentIds = attachmentIds;
    return ChatMessage(
      id: 'message-${textSendIds.length + 1}',
      channelId: channelId,
      clientMessageId: clientMessageId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 20, 1),
      deleted: false,
      revision: 1,
      replyToId: replyToId,
      attachments: [
        for (final id in attachmentIds)
          MessageAttachment(id: id, originalName: 'file.txt', sizeBytes: 3),
      ],
    );
  }

  @override
  Future<ChatMessage> editMessage(
    String channelId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) async {
    await textEditGate?.future;
    editedRevision = expectedRevision;
    if (failTextEdits > 0) {
      failTextEdits--;
      throw const ApiFailure('Конфликт редакции', status: 409);
    }
    return ChatMessage(
      id: messageId,
      channelId: channelId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 20),
      deleted: false,
      revision: expectedRevision + 1,
    );
  }

  @override
  Future<DirectChatMessage> editDirectMessage(
    String directMessageId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) async {
    editedDirectRevision = expectedRevision;
    if (failDirectEdits > 0) {
      failDirectEdits--;
      throw const ApiFailure('Конфликт редакции', status: 409);
    }
    return DirectChatMessage(
      id: messageId,
      directMessageId: directMessageId,
      authorId: 'account-1',
      body: body,
      createdAt: DateTime.utc(2026, 9, 19),
      deleted: false,
      revision: expectedRevision + 1,
    );
  }

  @override
  Future<void> deleteMessage(String channelId, String messageId) async {
    deletedTextMessageId = messageId;
  }

  @override
  Future<void> deleteDirectMessage(
    String directMessageId,
    String messageId,
  ) async {
    deletedDirectMessageId = messageId;
  }

  @override
  Future<MessageAttachment> uploadChannelAttachment(
    String channelId,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadedTextChannelId = channelId;
    return MessageAttachment(
      id: 'text-file',
      originalName: fileName,
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<MessageAttachment> uploadDirectMessageAttachment(
    String directMessageId,
    String fileName,
    Uint8List bytes, {
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadedDirectMessageId = directMessageId;
    return MessageAttachment(
      id: 'dm-file',
      originalName: fileName,
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<(String, VoiceCredential)> voiceCredential(
    String channelId, {
    bool transfer = false,
  }) async {
    voiceTransferAttempts.add(transfer);
    if (transfer) {
      if (transferFailure case final failure?) throw failure;
    } else if (voiceFailure case final failure?) {
      throw failure;
    }
    return (
      'lease-1',
      const VoiceCredential(url: 'wss://voice.example.test', token: 'token'),
    );
  }
}

class _RecoveringRosterApi extends _FakeApi {
  _RecoveringRosterApi(super.value);

  int rosterAttempts = 0;

  @override
  Future<http.StreamedResponse> voiceRosterEvents() async {
    rosterAttempts++;
    if (rosterAttempts == 1) {
      throw const ApiFailure(
        'Нет связи со списком голосовых каналов.',
        status: 503,
      );
    }
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          'data: {"channels":[{"channel_id":"voice-channel","participants":[]}] }\n\n',
        ),
      ),
      200,
    );
  }
}

class _StaleRosterApi extends _FakeApi {
  _StaleRosterApi(super.value);

  int rosterAttempts = 0;

  @override
  Future<http.StreamedResponse> voiceRosterEvents() async {
    rosterAttempts++;
    if (rosterAttempts > 1) {
      throw const ApiFailure(
        'Нет связи со списком голосовых каналов.',
        status: 503,
      );
    }
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          'data: {"channels":[{"channel_id":"voice-channel","participants":[]}]}\n\n',
        ),
      ),
      200,
    );
  }
}

class _RosterStreamRecoversBeforeStaleTimeout extends _FakeApi {
  _RosterStreamRecoversBeforeStaleTimeout(super.value);

  int rosterAttempts = 0;
  final recovered = Completer<void>();

  @override
  Future<http.StreamedResponse> voiceRosterEvents() async {
    rosterAttempts++;
    if (rosterAttempts == 2) {
      throw const ApiFailure(
        'Нет связи со списком голосовых каналов.',
        status: 503,
      );
    }
    if (rosterAttempts >= 3 && !recovered.isCompleted) recovered.complete();
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          'data: {"channels":[{"channel_id":"voice-channel","participants":[]}] }\n\n',
        ),
      ),
      200,
    );
  }
}
