import 'dart:async';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;
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
    expect(state.selectedAudioInputId, isNull);
  });

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

  test('offers an explicit transfer for an existing voice lease', () async {
    final api = _FakeApi(
      topology,
      voiceFailure: const ApiFailure(
        'Голос уже подключён в другом окне',
        status: 409,
        code: 'ACTIVE_VOICE_LEASE',
      ),
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
    expect(state.transferRequired, isTrue);
    expect(state.error, contains('Перенесите подключение'));
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
}

class _FakeApi extends ApiClient {
  _FakeApi(
    this.value, {
    this.voiceFailure,
    this.includeDirectMessage = false,
    this.paginated = false,
  });
  ChannelTopology value;
  final ApiFailure? voiceFailure;
  final bool includeDirectMessage;
  final bool paginated;
  int olderPageRequests = 0;
  String? advancedMessageId;
  String? advancedTextChannelId;
  String? advancedTextMessageId;
  int textReadAdvances = 0;
  int? editedRevision;
  bool passwordResetCompleted = false;
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
  final textSendIds = <String>[];
  final directSendIds = <String>[];

  @override
  bool get realtimeEnabled => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> maintenanceActive() async => false;

  @override
  Future<SessionUser?> currentSession() async =>
      const SessionUser(accountId: 'account-1', role: 'MEMBER');

  @override
  Future<OwnProfile> ownProfile() async => const OwnProfile(
    accountId: 'account-1',
    login: 'member',
    displayName: 'Участник',
    role: 'MEMBER',
  );

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
  }) async => DirectChatMessagePage(messages: await directMessageHistory(id));

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
            revision: 1,
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
    int expectedRevision,
  ) async {
    editedRevision = expectedRevision;
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
  Future<(String, VoiceCredential)> voiceCredential(
    String channelId, {
    bool transfer = false,
  }) async {
    if (voiceFailure case final failure?) throw failure;
    return (
      'lease-1',
      const VoiceCredential(url: 'wss://voice.example.test', token: 'token'),
    );
  }
}
