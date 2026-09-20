import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage;
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'services/api_client.dart';

enum AppPhase { loading, signedOut, ready }

enum VoicePhase { idle, joining, connected, listener, leaving, error }

class AppState extends ChangeNotifier {
  AppState(this.api);
  final ApiClient api;
  final Uuid _uuid = const Uuid();
  AppPhase phase = AppPhase.loading;
  SessionUser? user;
  ChannelTopology? topology;
  GuildChannel? selectedChannel;
  List<ChatMessage> messages = const [];
  bool loadingMessages = false;
  bool sending = false;
  String? error;
  VoicePhase voicePhase = VoicePhase.idle;
  GuildChannel? voiceChannel;
  bool microphoneMuted = false;
  bool deafened = false;
  bool transferRequired = false;
  bool _mutedBeforeDeafen = false;
  Room? _room;
  String? _leaseId;

  String get serverUrl => api.baseUrl;

  Future<void> initialize() async {
    try {
      await api.initialize();
      user = await api.currentSession();
      if (user == null) {
        phase = AppPhase.signedOut;
      } else {
        phase = AppPhase.ready;
        await refreshTopology();
      }
    } catch (cause) {
      phase = AppPhase.signedOut;
      error = _message(cause);
    }
    notifyListeners();
  }

  Future<void> setServer(String value) async {
    await leaveVoice();
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
      await refreshTopology();
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
    topology = null;
    selectedChannel = null;
    messages = const [];
    phase = AppPhase.signedOut;
    notifyListeners();
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
