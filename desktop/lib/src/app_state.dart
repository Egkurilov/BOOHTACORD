import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage;
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'services/api_client.dart';

enum AppPhase { loading, signedOut, ready }

enum VoicePhase { idle, joining, connected, listener, leaving, error }

enum NavigationSection { channels, directMessages }

enum WorkspacePanel { none, profile, audio, admin, search }

class AppState extends ChangeNotifier {
  AppState(this.api);
  final ApiClient api;
  final Uuid _uuid = const Uuid();
  AppPhase phase = AppPhase.loading;
  SessionUser? user;
  OwnProfile? profile;
  ChannelTopology? topology;
  List<GuildMember> members = const [];
  List<DirectConversation> directMessages = const [];
  List<DirectCandidate> directMessageCandidates = const [];
  DirectConversation? selectedDirectMessage;
  List<DirectChatMessage> directMessageHistory = const [];
  NavigationSection navigationSection = NavigationSection.channels;
  WorkspacePanel workspacePanel = WorkspacePanel.none;
  GuildChannel? selectedChannel;
  List<ChatMessage> messages = const [];
  bool loadingMessages = false;
  bool sending = false;
  bool loadingDirectMessages = false;
  bool realtimeConnected = false;
  bool profileLoading = false;
  bool profileSaving = false;
  String? error;
  VoicePhase voicePhase = VoicePhase.idle;
  GuildChannel? voiceChannel;
  bool microphoneMuted = false;
  bool deafened = false;
  bool transferRequired = false;
  bool _mutedBeforeDeafen = false;
  Room? _room;
  String? _leaseId;
  WebSocket? _realtimeSocket;
  StreamSubscription<dynamic>? _realtimeSubscription;
  Timer? _realtimeRetry;
  int _realtimeAttempt = 0;
  final Set<String> _realtimeEventIds = <String>{};
  String? _lastReadDirectMessageId;

  String get serverUrl => api.baseUrl;
  Room? get room => _room;

  Future<void> initialize() async {
    try {
      await api.initialize();
      user = await api.currentSession();
      if (user == null) {
        phase = AppPhase.signedOut;
      } else {
        phase = AppPhase.ready;
        await Future.wait([
          refreshTopology(),
          refreshMembers(),
          refreshDirectMessages(),
          refreshProfile(),
        ]);
        unawaited(_connectRealtime());
      }
    } catch (cause) {
      phase = AppPhase.signedOut;
      error = _message(cause);
    }
    notifyListeners();
  }

  Future<void> setServer(String value) async {
    await leaveVoice();
    await _closeRealtime();
    await api.setBaseUrl(value);
    user = null;
    topology = null;
    selectedChannel = null;
    phase = AppPhase.signedOut;
    error = null;
    notifyListeners();
  }

  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) async {
    error = null;
    notifyListeners();
    try {
      await api.authenticate(login, password, register: register);
      user = await api.currentSession();
      phase = AppPhase.ready;
      await Future.wait([
        refreshTopology(),
        refreshMembers(),
        refreshDirectMessages(),
        refreshProfile(),
      ]);
      unawaited(_connectRealtime());
    } catch (cause) {
      error = _message(cause);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await leaveVoice();
    await api.logout();
    user = null;
    profile = null;
    topology = null;
    selectedChannel = null;
    messages = const [];
    members = const [];
    directMessages = const [];
    directMessageCandidates = const [];
    selectedDirectMessage = null;
    directMessageHistory = const [];
    phase = AppPhase.signedOut;
    await _closeRealtime();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    profileLoading = true;
    notifyListeners();
    try {
      profile = await api.ownProfile();
    } catch (cause) {
      error = _message(cause);
    } finally {
      profileLoading = false;
      notifyListeners();
    }
  }

  void toggleWorkspacePanel(WorkspacePanel panel) {
    workspacePanel = workspacePanel == panel ? WorkspacePanel.none : panel;
    error = null;
    notifyListeners();
  }

  Future<bool> saveDisplayName(String value) async {
    final displayName = value.trim();
    if (displayName.isEmpty || displayName.runes.length > 64) {
      error = 'Имя должно содержать от 1 до 64 символов.';
      notifyListeners();
      return false;
    }
    profileSaving = true;
    error = null;
    notifyListeners();
    try {
      profile = await api.updateOwnProfile(displayName);
      await refreshMembers();
      return true;
    } catch (cause) {
      error = _message(cause);
      return false;
    } finally {
      profileSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updatePassword(String current, String next) async {
    if (current.runes.length < 12 ||
        next.runes.length < 12 ||
        next.runes.length > 128) {
      error = 'Пароль должен содержать от 12 до 128 символов.';
      notifyListeners();
      return false;
    }
    profileSaving = true;
    error = null;
    notifyListeners();
    try {
      await api.changePassword(current, next);
      return true;
    } catch (cause) {
      error = _message(cause);
      return false;
    } finally {
      profileSaving = false;
      notifyListeners();
    }
  }

  Future<void> refreshMembers() async {
    try {
      members = await api.members();
    } catch (cause) {
      error = _message(cause);
    }
    notifyListeners();
  }

  Future<void> refreshDirectMessages() async {
    try {
      directMessages = await api.directMessages();
      if (navigationSection == NavigationSection.directMessages) {
        directMessageCandidates = await api.directMessageCandidates();
      }
    } catch (cause) {
      error = _message(cause);
    }
    notifyListeners();
  }

  Future<void> showDirectMessages() async {
    workspacePanel = WorkspacePanel.none;
    navigationSection = NavigationSection.directMessages;
    selectedChannel = null;
    error = null;
    notifyListeners();
    await refreshDirectMessages();
  }

  void showChannels() {
    workspacePanel = WorkspacePanel.none;
    navigationSection = NavigationSection.channels;
    selectedDirectMessage = null;
    directMessageHistory = const [];
    final all = topology?.categories.expand((category) => category.channels);
    selectedChannel ??= all
        ?.where((channel) => channel.kind == ChannelKind.text)
        .firstOrNull;
    notifyListeners();
  }

  Future<void> openDirectConversation(DirectConversation conversation) async {
    selectedDirectMessage = conversation;
    selectedChannel = null;
    loadingDirectMessages = true;
    error = null;
    notifyListeners();
    try {
      directMessageHistory = await api.directMessageHistory(conversation.id);
    } catch (cause) {
      error = _message(cause);
    } finally {
      loadingDirectMessages = false;
      notifyListeners();
    }
  }

  Future<void> markSelectedDirectMessageRead() async {
    final conversation = selectedDirectMessage;
    if (conversation == null || loadingDirectMessages) return;
    final visibleOtherMessages = directMessageHistory
        .where((message) => message.authorId != user?.accountId)
        .toList();
    if (visibleOtherMessages.isEmpty) return;
    final messageId = visibleOtherMessages.last.id;
    if (_lastReadDirectMessageId == messageId) return;
    _lastReadDirectMessageId = messageId;
    try {
      await api.advanceDirectMessageReadCursor(conversation.id, messageId);
      if (selectedDirectMessage?.id != conversation.id) return;
      directMessages = directMessages
          .map(
            (value) =>
                value.id == conversation.id ? value.withUnreadCount(0) : value,
          )
          .toList(growable: false);
      notifyListeners();
    } catch (cause) {
      _lastReadDirectMessageId = null;
      error = _message(cause);
      notifyListeners();
    }
  }

  Future<void> createDirectConversation(DirectCandidate candidate) async {
    try {
      final id = await api.openDirectMessage(candidate.id);
      await refreshDirectMessages();
      final conversation = directMessages
          .where((value) => value.id == id)
          .firstOrNull;
      if (conversation != null) await openDirectConversation(conversation);
    } catch (cause) {
      error = _message(cause);
      notifyListeners();
    }
  }

  Future<bool> sendDirect(String body) async {
    final conversation = selectedDirectMessage;
    final trimmed = body.trim();
    if (conversation == null || trimmed.isEmpty || trimmed.length > 8000) {
      return false;
    }
    sending = true;
    error = null;
    notifyListeners();
    try {
      final message = await api.sendDirectMessage(
        conversation.id,
        _uuid.v4(),
        trimmed,
      );
      directMessageHistory = [...directMessageHistory, message];
      return true;
    } catch (cause) {
      error = _message(cause);
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<bool> editDirect(DirectChatMessage message, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 8000) return false;
    try {
      final edited = await api.editDirectMessage(
        message.directMessageId,
        message.id,
        trimmed,
        message.revision,
      );
      directMessageHistory = directMessageHistory
          .map((value) => value.id == edited.id ? edited : value)
          .toList(growable: false);
      notifyListeners();
      return true;
    } on ApiFailure catch (cause) {
      error = cause.message;
      if (cause.status == 409 && selectedDirectMessage != null) {
        await openDirectConversation(selectedDirectMessage!);
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteDirect(DirectChatMessage message) async {
    try {
      await api.deleteDirectMessage(message.directMessageId, message.id);
      if (selectedDirectMessage != null) {
        await openDirectConversation(selectedDirectMessage!);
      }
    } catch (cause) {
      error = _message(cause);
      notifyListeners();
    }
  }

  Future<void> refreshTopology() async {
    try {
      topology = await api.topology();
      final all = topology!.categories.expand((category) => category.channels);
      selectedChannel ??= all
          .where((channel) => channel.kind == ChannelKind.text)
          .firstOrNull;
      if (selectedChannel?.kind == ChannelKind.text) {
        await selectChannel(selectedChannel!);
      }
    } catch (cause) {
      error = _message(cause);
    }
    notifyListeners();
  }

  Future<void> selectChannel(GuildChannel channel) async {
    workspacePanel = WorkspacePanel.none;
    navigationSection = NavigationSection.channels;
    selectedDirectMessage = null;
    selectedChannel = channel;
    messages = const [];
    error = null;
    notifyListeners();
    if (channel.kind == ChannelKind.text) {
      loadingMessages = true;
      notifyListeners();
      try {
        messages = await api.messages(channel.id);
      } catch (cause) {
        error = _message(cause);
      } finally {
        loadingMessages = false;
        notifyListeners();
      }
    }
  }

  Future<void> _connectRealtime() async {
    if (!api.realtimeEnabled ||
        phase != AppPhase.ready ||
        _realtimeSocket != null) {
      return;
    }
    try {
      final socket = await api.openRealtime();
      if (phase != AppPhase.ready) {
        await socket.close();
        return;
      }
      _realtimeSocket = socket;
      _realtimeAttempt = 0;
      _realtimeSubscription = socket.listen(
        _handleRealtimeData,
        onDone: _handleRealtimeClosed,
        onError: (_) => _handleRealtimeClosed(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRealtimeRetry();
    }
  }

  void _handleRealtimeData(dynamic raw) {
    if (raw is! String) return;
    try {
      final event = jsonDecode(raw) as Map<String, dynamic>;
      final eventId = event['event_id'] as String?;
      final kind = event['kind'] as String?;
      final payload = event['payload'] as Map<String, dynamic>? ?? const {};
      if (eventId == null || !_realtimeEventIds.add(eventId)) return;
      if (_realtimeEventIds.length > 1000) _realtimeEventIds.clear();
      switch (kind) {
        case 'connection.ready':
          realtimeConnected = true;
        case 'presence.snapshot':
          final online =
              ((payload['online_user_ids'] as List<dynamic>? ?? const []))
                  .whereType<String>()
                  .toSet();
          members = members
              .map(
                (member) => member.withPresence(
                  online.contains(member.id)
                      ? MemberPresence.online
                      : MemberPresence.offline,
                ),
              )
              .toList(growable: false);
        case 'presence.changed':
          final id = payload['user_id'] as String?;
          final value = payload['presence'] == 'online'
              ? MemberPresence.online
              : MemberPresence.offline;
          members = members
              .map(
                (member) =>
                    member.id == id ? member.withPresence(value) : member,
              )
              .toList(growable: false);
        case 'message.created':
          if (selectedChannel?.id == payload['channel_id']) {
            unawaited(selectChannel(selectedChannel!));
          }
        case 'channel.updated':
          unawaited(refreshTopology());
        case 'connection.resync_required':
          unawaited(refreshTopology());
          unawaited(refreshMembers());
          if (selectedChannel?.kind == ChannelKind.text) {
            unawaited(selectChannel(selectedChannel!));
          }
        case 'voice.lease_revoked':
          unawaited(_handleVoiceLeaseRevoked());
      }
      notifyListeners();
    } catch (_) {
      // Unknown or malformed future events are ignored and grant no authority.
    }
  }

  Future<void> _handleVoiceLeaseRevoked() async {
    await _room?.disconnect();
    _room = null;
    _leaseId = null;
    voiceChannel = null;
    voicePhase = VoicePhase.idle;
    microphoneMuted = false;
    deafened = false;
    error = 'Голосовое подключение отозвано сервером.';
    notifyListeners();
  }

  void _handleRealtimeClosed() {
    _realtimeSocket = null;
    realtimeConnected = false;
    notifyListeners();
    _scheduleRealtimeRetry();
  }

  void _scheduleRealtimeRetry() {
    if (phase != AppPhase.ready || _realtimeRetry != null) return;
    final seconds = 1 << _realtimeAttempt.clamp(0, 5);
    _realtimeAttempt++;
    _realtimeRetry = Timer(Duration(seconds: seconds), () {
      _realtimeRetry = null;
      unawaited(_connectRealtime());
    });
  }

  Future<void> _closeRealtime() async {
    _realtimeRetry?.cancel();
    _realtimeRetry = null;
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    await _realtimeSocket?.close();
    _realtimeSocket = null;
    realtimeConnected = false;
  }

  @override
  void dispose() {
    _realtimeRetry?.cancel();
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_realtimeSocket?.close());
    unawaited(_room?.disconnect());
    super.dispose();
  }

  Future<bool> send(String body) async {
    final channel = selectedChannel;
    final trimmed = body.trim();
    if (channel == null ||
        channel.kind != ChannelKind.text ||
        trimmed.isEmpty ||
        trimmed.length > 8000) {
      return false;
    }
    sending = true;
    error = null;
    notifyListeners();
    try {
      final message = await api.sendMessage(channel.id, _uuid.v4(), trimmed);
      messages = [...messages, message];
      return true;
    } catch (cause) {
      error = _message(cause);
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<bool> editText(ChatMessage message, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 8000) return false;
    try {
      final edited = await api.editMessage(
        message.channelId,
        message.id,
        trimmed,
        message.revision,
      );
      messages = messages
          .map((value) => value.id == edited.id ? edited : value)
          .toList(growable: false);
      notifyListeners();
      return true;
    } on ApiFailure catch (cause) {
      error = cause.message;
      if (cause.status == 409 && selectedChannel != null) {
        await selectChannel(selectedChannel!);
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteText(ChatMessage message) async {
    try {
      await api.deleteMessage(message.channelId, message.id);
      if (selectedChannel != null) await selectChannel(selectedChannel!);
    } catch (cause) {
      error = _message(cause);
      notifyListeners();
    }
  }

  Future<void> joinVoice(GuildChannel channel, {bool transfer = false}) async {
    if (channel.admissionClosed) return;
    voicePhase = VoicePhase.joining;
    error = null;
    transferRequired = false;
    notifyListeners();
    Room? pendingRoom;
    try {
      final result = await api.voiceCredential(channel.id, transfer: transfer);
      _leaseId = result.$1;
      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      pendingRoom = room;
      await room.connect(result.$2.url, result.$2.token);
      _room = room;
      voiceChannel = channel;
      try {
        await room.localParticipant?.setMicrophoneEnabled(true);
        voicePhase = VoicePhase.connected;
      } catch (_) {
        microphoneMuted = true;
        voicePhase = VoicePhase.listener;
      }
    } catch (cause) {
      try {
        await pendingRoom?.disconnect();
      } catch (_) {}
      final leaseId = _leaseId;
      if (leaseId != null) {
        try {
          await api.releaseVoice(leaseId);
        } catch (_) {}
      }
      _room = null;
      _leaseId = null;
      voiceChannel = null;
      voicePhase = VoicePhase.error;
      transferRequired =
          cause is ApiFailure && cause.code == 'ACTIVE_VOICE_LEASE';
      error = transferRequired
          ? 'Голос уже подключён в другом окне. Перенесите подключение сюда или выйдите из того окна.'
          : _message(cause);
    }
    notifyListeners();
  }

  Future<void> toggleMicrophone() async {
    if (_room == null || deafened) return;
    microphoneMuted = !microphoneMuted;
    try {
      await _room!.localParticipant?.setMicrophoneEnabled(!microphoneMuted);
    } catch (cause) {
      microphoneMuted = true;
      error = _message(cause);
    }
    notifyListeners();
  }

  Future<void> toggleDeafen() async {
    final room = _room;
    if (room == null) return;
    if (!deafened) {
      _mutedBeforeDeafen = microphoneMuted;
      deafened = true;
      if (!microphoneMuted) {
        microphoneMuted = true;
        await room.localParticipant?.setMicrophoneEnabled(false);
      }
      for (final participant in room.remoteParticipants.values) {
        for (final publication in participant.audioTrackPublications) {
          await publication.disable();
        }
      }
    } else {
      deafened = false;
      for (final participant in room.remoteParticipants.values) {
        for (final publication in participant.audioTrackPublications) {
          await publication.enable();
        }
      }
      if (!_mutedBeforeDeafen) {
        microphoneMuted = false;
        try {
          await room.localParticipant?.setMicrophoneEnabled(true);
        } catch (cause) {
          microphoneMuted = true;
          error = _message(cause);
        }
      }
    }
    notifyListeners();
  }

  Future<void> leaveVoice() async {
    if (_room == null && _leaseId == null) return;
    voicePhase = VoicePhase.leaving;
    notifyListeners();
    final leaseId = _leaseId;
    try {
      await _room?.disconnect();
    } catch (_) {}
    if (leaseId != null) {
      try {
        await api.releaseVoice(leaseId);
      } catch (cause) {
        error = _message(cause);
      }
    }
    _room = null;
    _leaseId = null;
    voiceChannel = null;
    transferRequired = false;
    microphoneMuted = false;
    deafened = false;
    _mutedBeforeDeafen = false;
    voicePhase = VoicePhase.idle;
    notifyListeners();
  }

  String _message(Object cause) {
    if (cause is ApiFailure) return cause.message;
    if (cause is ConnectException) {
      final code = cause.statusCode > 0 ? ' (${cause.statusCode})' : '';
      return switch (cause.reason) {
        ConnectionErrorReason.NotAllowed =>
          'LiveKit отклонил подключение$code. Голосовой lease освобождён.',
        ConnectionErrorReason.Timeout =>
          'LiveKit не ответил вовремя. Голосовой lease освобождён.',
        ConnectionErrorReason.InternalError =>
          'Не удалось подключиться к LiveKit$code: ${cause.message}',
      };
    }
    if (cause is MediaConnectException) {
      return 'Не удалось установить WebRTC-соединение: ${cause.message}';
    }
    if (cause is LiveKitException) return 'Ошибка LiveKit: ${cause.message}';
    return 'Не удалось выполнить действие: ${cause.runtimeType}.';
  }
}
