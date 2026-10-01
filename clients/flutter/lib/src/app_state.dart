import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter_background/flutter_background.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'guild_presence_state.dart';
import 'features/audio/devices/controller.dart';
import 'features/session/lifecycle/controller.dart';
import 'models.dart';
import 'services/api_client.dart';
import 'services/composer_draft_memory.dart';
import 'services/audio_preferences.dart';
import 'services/android_audio_devices.dart';
import 'services/password_reset_link.dart';
import 'services/screen_share_quality.dart';
import 'services/screen_share_metrics.dart';
import 'services/screen_share_metrics_generation_gate.dart';
import 'services/native_notifications.dart';
import 'services/voice_lease_revocation.dart';
import 'services/voice_volume_preferences.dart';
import 'services/voice_reconnect_policy.dart';
import 'services/voice_stream_start_tracker.dart';
import 'services/voice_connection_quality.dart';
import 'services/voice_roster_events.dart';
import 'services/screen_thumbnail.dart';
import 'telemetry/report_media/sender.dart';
import 'telemetry/report_media/sender_sample.dart';
import 'telemetry/report_media/connection.dart';

export 'features/session/lifecycle/types.dart';

enum VoicePhase {
  idle,
  joining,
  connected,
  listener,
  reconnecting,
  leaving,
  error,
}

enum ScreenSharePhase { idle, starting, sharing, stopping, error }

enum AudioActivationMode { vad, ptt }

enum NavigationSection { channels, directMessages }

enum WorkspacePanel { none, profile, audio, admin, search, searchContext }

enum MessageEditStatus { saved, conflict, error, stale }

typedef MessageEditOutcome = ({MessageEditStatus kind, String? message});

String screenShareFailureDetail(Object cause) {
  if (cause is String && cause.trim().isNotEmpty) return cause.trim();
  if (cause is StateError) return cause.message;
  if (cause is PlatformException) {
    final message = cause.message?.trim();
    if (message != null && message.isNotEmpty) return message;
    final code = cause.code.trim();
    if (code.isNotEmpty) return code;
  }
  final detail = cause.toString().trim();
  if (detail.isNotEmpty && detail != cause.runtimeType.toString()) {
    return detail;
  }
  return cause.runtimeType.toString();
}

VideoDimensions? _screenShareCaptureDimensions(LocalVideoTrack track) {
  try {
    final settings = track.mediaStreamTrack.getSettings();
    final width = settings['width'];
    final height = settings['height'];
    if (width is num && height is num && width > 0 && height > 0) {
      return VideoDimensions(width.round(), height.round());
    }
  } catch (_) {
    // Some platform implementations don't expose capture settings.
  }
  return null;
}

class AppState extends ChangeNotifier {
  static const _voiceStreamSoundPreferenceKey = 'voice-screen-start-sound:v1';

  AppState(
    this.api, {
    this.startupSessionTimeout = const Duration(seconds: 20),
    this.voiceRosterRetryDelay = const Duration(seconds: 2),
    this.voiceRosterStaleTimeout = const Duration(seconds: 10),
    Future<List<MediaDevice>> Function()? audioDeviceLoader,
    Stream<List<MediaDevice>>? audioDeviceChanges,
    NativeNotificationService? nativeNotifications,
  }) : _nativeNotifications =
           nativeNotifications ?? NativeNotificationService() {
    _session = SessionController(
      api,
      startupTimeout: startupSessionTimeout,
      effects: SessionEffects(
        initialize: _initializeSessionPlatform,
        prepare: _prepareSessionAccount,
        ready: _loadSessionWorkspace,
        closeMedia: leaveVoice,
        closeRealtime: _closeRealtime,
        clearAccount: _clearSignedOutAccount,
        expireAccount: _clearExpiredAccount,
        beforeServerChange: () {
          loadingMessages = false;
          _stopVoiceRosterEvents();
        },
        clearServer: _clearServerAccount,
        error: (value) => error = value,
        message: _message,
      ),
    )..addListener(notifyListeners);
    _audioDevices = AudioDeviceController(
      readRoom: () => _room,
      loader: audioDeviceLoader,
      changes: audioDeviceChanges,
    )..addListener(notifyListeners);
    api.onUnauthorized = _handleUnauthorized;
  }

  final Duration voiceRosterRetryDelay;
  final Duration voiceRosterStaleTimeout;

  final ApiClient api;
  late final AudioDeviceController _audioDevices;
  late final SessionController _session;
  @visibleForTesting
  final Duration startupSessionTimeout;
  final NativeNotificationService _nativeNotifications;
  final Uuid _uuid = const Uuid();
  AppPhase get phase => _session.phase;
  set phase(AppPhase value) => _session.phase = value;
  SessionUser? get user => _session.user;
  set user(SessionUser? value) => _session.user = value;
  OwnProfile? profile;
  ChannelTopology? topology;
  List<GuildMember> members = const [];
  final GuildPresenceState guildPresence = GuildPresenceState();
  bool membersLoading = false;
  String? membersError;
  List<VoiceRoomRoster>? voiceRosters;
  String? voiceRosterError;
  List<DirectConversation> directMessages = const [];
  List<DirectCandidate> directMessageCandidates = const [];
  DirectConversation? selectedDirectMessage;
  List<DirectChatMessage> directMessageHistory = const [];
  String? nextDirectMessageCursor;
  bool loadingOlderDirectMessages = false;
  NavigationSection navigationSection = NavigationSection.channels;
  WorkspacePanel workspacePanel = WorkspacePanel.none;
  SearchMessage? searchContextMessage;
  String searchContextHeading = 'Контекст найденного сообщения';
  List<ChatMessage> searchContextTextMessages = const [];
  List<DirectChatMessage> searchContextDirectMessages = const [];
  bool loadingSearchContext = false;
  String? searchContextError;
  GuildChannel? _searchOriginChannel;
  DirectConversation? _searchOriginDirectMessage;
  int _searchContextSequence = 0;
  GuildChannel? selectedChannel;
  List<ChatMessage> messages = const [];
  String? nextMessageCursor;
  bool loadingOlderMessages = false;
  bool loadingMessages = false;
  bool _textHistoryHasLoadedOlderPages = false;
  int _textHistoryLoadSequence = 0;
  bool sending = false;
  bool loadingDirectMessages = false;
  bool realtimeConnected = false;
  bool maintenanceActive = false;
  bool profileLoading = false;
  String? profileLoadError;
  bool profileSaving = false;
  bool get logoutBusy => _session.logoutBusy;
  set logoutBusy(bool value) => _session.logoutBusy = value;
  String? get logoutError => _session.logoutError;
  set logoutError(String? value) => _session.logoutError = value;
  bool resetRoute = false;
  String? resetToken;
  bool resetPending = false;
  bool resetCompleted = false;
  bool resetUnusable = false;
  String? resetError;
  bool focusLoginOnMount = false;
  int avatarRevision = 0;
  String? error;
  VoicePhase voicePhase = VoicePhase.idle;
  GuildChannel? voiceChannel;
  bool microphoneMuted = false;
  bool microphoneUnavailable = false;
  bool deafened = false;
  bool deafenChanging = false;
  bool voiceStreamSoundEnabled = true;
  bool voiceStreamStartNotice = false;
  ScreenSharePhase screenSharePhase = ScreenSharePhase.idle;
  String? screenShareError;
  final Map<String, Uint8List> screenThumbnails = {};
  ScreenShareQuality screenShareQuality =
      defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS
      ? ScreenShareQuality.balanced
      : ScreenShareQuality.desktopDefault;
  List<MediaDevice> get audioInputDevices => _audioDevices.audioInputDevices;
  set audioInputDevices(List<MediaDevice> value) =>
      _audioDevices.audioInputDevices = value;
  List<MediaDevice> get audioOutputDevices => _audioDevices.audioOutputDevices;
  set audioOutputDevices(List<MediaDevice> value) =>
      _audioDevices.audioOutputDevices = value;
  String? get selectedAudioInputId => _audioDevices.selectedAudioInputId;
  set selectedAudioInputId(String? value) =>
      _audioDevices.selectedAudioInputId = value;
  String? get selectedAudioOutputId => _audioDevices.selectedAudioOutputId;
  set selectedAudioOutputId(String? value) =>
      _audioDevices.selectedAudioOutputId = value;
  AudioProcessingPreferences get audioProcessing =>
      _audioDevices.audioProcessing;
  set audioProcessing(AudioProcessingPreferences value) =>
      _audioDevices.audioProcessing = value;
  bool get audioDevicesLoading => _audioDevices.audioDevicesLoading;
  set audioDevicesLoading(bool value) =>
      _audioDevices.audioDevicesLoading = value;
  bool get audioDeviceScanFailed => _audioDevices.audioDeviceScanFailed;
  set audioDeviceScanFailed(bool value) =>
      _audioDevices.audioDeviceScanFailed = value;
  String? get audioSettingsError => _audioDevices.audioSettingsError;
  set audioSettingsError(String? value) =>
      _audioDevices.audioSettingsError = value;
  String? get audioDeviceWarning => _audioDevices.audioDeviceWarning;
  set audioDeviceWarning(String? value) =>
      _audioDevices.audioDeviceWarning = value;
  AudioActivationMode audioActivationMode = AudioActivationMode.vad;
  int? pushToTalkKeyId;
  String? pushToTalkKeyLabel;
  String? audioActivationError;
  bool pushToTalkPressed = false;
  bool _mutedBeforeDeafen = false;
  bool _microphoneMutedBeforePtt = false;
  Room? _room;
  int? _voicePingMs;
  EventsListener<RoomEvent>? _voiceEvents;
  VoiceVolumePreferences? _voiceVolumePreferences;
  final Set<String> _mutedScreenShareAudioIdentities = <String>{};
  AudioPreferences? get _audioPreferences => _audioDevices.preferences;
  set _audioPreferences(AudioPreferences? value) =>
      _audioDevices.preferences = value;
  String? _leaseId;
  bool _listenerOnly = false;
  bool _voiceAdmissionPending = false;
  final Map<String, String> _revokedVoiceLeasesDuringJoin = {};
  WebSocket? _realtimeSocket;
  StreamSubscription<dynamic>? _realtimeSubscription;
  Timer? _realtimeRetry;
  Timer? _maintenanceTimer;
  StreamSubscription<String>? _voiceRosterSubscription;
  Completer<void>? _voiceRosterStreamDone;
  Timer? _voiceRosterRetryTimer;
  Timer? _voiceRosterStaleTimer;
  Completer<void>? _voiceRosterRetryDone;
  bool _voiceRosterWatching = false;
  Timer? _voiceStreamNoticeTimer;
  Timer? _voiceConnectionStatsTimer;
  int _voiceConnectionStatsRevision = 0;
  bool _voiceConnectionStatsBusy = false;
  final VoiceStreamStartTracker _voiceStreamStartTracker =
      VoiceStreamStartTracker();
  Timer? _screenShareMetricsTimer;
  Timer? _screenThumbnailTimer;
  bool _screenThumbnailBusy = false;
  ScreenThumbnailCaptureResult? _screenThumbnailLastLoggedResult;
  final ScreenThumbnailCaptureQueue _screenThumbnailCaptureQueue =
      ScreenThumbnailCaptureQueue();
  ScreenPreviewSubscriptionQueue? _screenPreviewSubscriptionQueue;
  final Map<String, Completer<RemoteVideoTrack?>> _screenPreviewTrackWaiters =
      <String, Completer<RemoteVideoTrack?>>{};
  String? _selectedRemoteScreenViewerIdentity;
  final Map<String, String> _screenThumbnailRemoteTrackIds = <String, String>{};
  LocalVideoTrack? _screenShareMetricsTrack;
  ScreenShareSenderSnapshot? _previousScreenShareMetrics;
  final _screenShareMetricsGate = ScreenShareMetricsGenerationGate();
  final _senderMediaTelemetry = SenderMediaTelemetry();
  int _voiceRosterRevision = 0;
  bool _voiceRosterLoading = false;
  bool _notificationAppIsForeground = true;
  int _realtimeAttempt = 0;
  final Set<String> _realtimeEventIds = <String>{};
  final Map<String, String> _sendRetryIds = <String, String>{};
  final Map<String, ChatMessage> _pendingTextSends = {};
  final Map<String, DirectChatMessage> _pendingDirectSends = {};
  String? _lastReadDirectMessageId;
  bool _checkingRealtimeSession = false;
  final Map<String, DateTime> _lastReadTextAt = {};
  final Map<String, DateTime> _pendingTextReadAt = {};
  final Set<String> _pendingTextReads = {};

  String get serverUrl => api.baseUrl;
  Room? get room => _room;
  ConnectionQuality get voiceConnectionQuality =>
      _room?.localParticipant?.connectionQuality ?? ConnectionQuality.unknown;
  int? get voicePingMs => _voicePingMs;
  bool get notificationsSupported => _nativeNotifications.supported;
  bool get notificationsEnabled => _nativeNotifications.enabled;
  NativeNotificationPermission get notificationPermission =>
      _nativeNotifications.permission;
  String? get notificationError => _nativeNotifications.error;

  Future<void> enableNotifications() async {
    await _nativeNotifications.enable();
    notifyListeners();
  }

  Future<void> disableNotifications() async {
    await _nativeNotifications.disable();
    notifyListeners();
  }

  Future<void> refreshNotificationStatus() async {
    await _nativeNotifications.refreshStatus();
    notifyListeners();
  }

  void setNotificationAppForeground(bool foreground) {
    _notificationAppIsForeground = foreground;
  }

  void reportError(String message) {
    error = message;
    notifyListeners();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  void openPasswordResetLink(String value) {
    resetToken = parsePasswordResetToken(api.baseUrl, value);
    resetRoute = true;
    resetPending = false;
    resetCompleted = false;
    resetUnusable = resetToken == null;
    resetError = resetUnusable
        ? 'Ссылка недействительна или срок её действия истёк. Попросите администратора выдать новую ссылку.'
        : null;
    error = null;
    notifyListeners();
  }

  Future<bool> completePasswordReset(String password) async {
    final token = resetToken;
    if (!resetRoute || token == null || resetPending || resetUnusable) {
      return false;
    }
    resetPending = true;
    resetError = null;
    notifyListeners();
    try {
      await api.completePasswordReset(token, password);
      resetToken = null;
      resetCompleted = true;
      return true;
    } catch (cause) {
      resetError = _message(cause);
      if (cause is ApiFailure && cause.status == 400) {
        resetToken = null;
        resetUnusable = true;
      }
      return false;
    } finally {
      resetPending = false;
      notifyListeners();
    }
  }

  void returnToLogin() {
    resetRoute = false;
    resetToken = null;
    resetPending = false;
    resetCompleted = false;
    resetUnusable = false;
    resetError = null;
    focusLoginOnMount = true;
    error = null;
    notifyListeners();
  }

  void _handleUnauthorized() {
    unawaited(_expireSession());
  }

  Future<void> _expireSession() => _session.expire();

  Future<void> _clearExpiredAccount() async {
    final ticket = _session.scope.capture();
    _textHistoryLoadSequence++;
    ComposerDraftMemory.clear();
    _stopVoiceRosterEvents();
    profile = null;
    profileLoadError = null;
    unawaited(_nativeNotifications.useAccount(null));
    topology = null;
    members = const [];
    voiceRosters = null;
    voiceRosterError = null;
    directMessages = const [];
    directMessageCandidates = const [];
    selectedDirectMessage = null;
    directMessageHistory = const [];
    nextDirectMessageCursor = null;
    selectedChannel = null;
    messages = const [];
    _sendRetryIds.clear();
    _pendingTextSends.clear();
    _pendingDirectSends.clear();
    nextMessageCursor = null;
    _textHistoryHasLoadedOlderPages = false;
    workspacePanel = WorkspacePanel.none;
    navigationSection = NavigationSection.channels;
    loadingMessages = false;
    loadingDirectMessages = false;
    sending = false;
    profileLoading = false;
    profileLoadError = null;
    profileSaving = false;
    voiceChannel = null;
    _mutedScreenShareAudioIdentities.clear();
    _leaseId = null;
    microphoneMuted = false;
    microphoneUnavailable = false;
    deafened = false;
    _listenerOnly = false;
    _voiceVolumePreferences = null;
    _audioPreferences = null;
    audioActivationMode = AudioActivationMode.vad;
    pushToTalkKeyId = null;
    pushToTalkKeyLabel = null;
    pushToTalkPressed = false;
    audioActivationError = null;
    voicePhase = VoicePhase.idle;
    _clearVoiceStreamNotice(resetTracker: true, notify: false);
    error = null;
    logoutError = null;
    _realtimeEventIds.clear();
    _lastReadTextAt.clear();
    _pendingTextReads.clear();
    _lastReadDirectMessageId = null;
    final room = _room;
    _room = null;
    notifyListeners();
    await Future.wait([
      _closeRealtime(),
      _disposeVoiceEvents(),
      if (room != null) room.disconnect(),
    ]);
    if (!ticket.isCurrent) return;
    error = null;
    notifyListeners();
  }

  Future<void> initialize() => _session.initialize();

  Future<void> _initializeSessionPlatform() async {
    final ticket = _session.scope.capture();
    await _loadVoiceStreamSoundPreference();
    if (!ticket.isActive) return;
    await _nativeNotifications.initialize();
    if (!ticket.isActive) return;
    unawaited(refreshMaintenance());
    _maintenanceTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(refreshMaintenance()),
    );
  }

  Future<void> _prepareSessionAccount(SessionUser account) async {
    final ticket = _session.scope.capture();
    await _nativeNotifications.useAccount(account.accountId);
    if (!ticket.isActive) return;
    await _loadAudioPreferences(account.accountId);
  }

  Future<void> _loadSessionWorkspace() async {
    final ticket = _session.scope.capture();
    await Future.wait([
      refreshTopology(),
      refreshMembers(),
      refreshDirectMessages(),
      refreshProfile(),
    ]);
    if (!ticket.isActive || phase != AppPhase.ready) return;
    _startVoiceRosterEvents();
    unawaited(_connectRealtime());
  }

  Future<void> _loadVoiceStreamSoundPreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      voiceStreamSoundEnabled =
          preferences.getBool(_voiceStreamSoundPreferenceKey) ?? true;
    } catch (_) {
      // The in-memory default remains enabled when preferences are unavailable.
    }
  }

  Future<void> setVoiceStreamSoundEnabled(bool enabled) async {
    if (voiceStreamSoundEnabled == enabled) return;
    voiceStreamSoundEnabled = enabled;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_voiceStreamSoundPreferenceKey, enabled);
    } catch (_) {
      // Keep the current-session preference even if persistence fails.
    }
  }

  void _observeVoiceStreamStarts(Room room) {
    final connected =
        voicePhase == VoicePhase.connected || voicePhase == VoicePhase.listener;
    final reconnecting = voicePhase == VoicePhase.reconnecting;
    if (!connected && !reconnecting) {
      _clearVoiceStreamNotice(resetTracker: true, notify: false);
      return;
    }

    final remoteScreenSharers = room.remoteParticipants.values
        .where(
          (participant) => participant.videoTrackPublications.any(
            (publication) => publication.source == TrackSource.screenShareVideo,
          ),
        )
        .map((participant) => participant.identity);
    final startedBy = _voiceStreamStartTracker.observe(
      remoteScreenSharers,
      connected: connected,
      reconnecting: reconnecting,
    );
    if (startedBy == null) return;

    _voiceStreamNoticeTimer?.cancel();
    voiceStreamStartNotice = true;
    _voiceStreamNoticeTimer = Timer(const Duration(seconds: 6), () {
      _voiceStreamNoticeTimer = null;
      voiceStreamStartNotice = false;
      notifyListeners();
    });
    if (voiceStreamSoundEnabled) {
      final sound = defaultTargetPlatform == TargetPlatform.android
          ? SystemSoundType.click
          : SystemSoundType.alert;
      unawaited(SystemSound.play(sound).catchError((Object _) {}));
    }
  }

  void _clearVoiceStreamNotice({
    required bool resetTracker,
    required bool notify,
  }) {
    _voiceStreamNoticeTimer?.cancel();
    _voiceStreamNoticeTimer = null;
    final changed = voiceStreamStartNotice;
    voiceStreamStartNotice = false;
    if (resetTracker) _voiceStreamStartTracker.reset();
    if (notify && changed) notifyListeners();
  }

  Future<void> setServer(String value) => _session.setServer(value);

  Future<void> _clearServerAccount() async {
    _audioPreferences = null;
    audioActivationMode = AudioActivationMode.vad;
    pushToTalkKeyId = null;
    pushToTalkKeyLabel = null;
    audioActivationError = null;
    selectedAudioInputId = null;
    selectedAudioOutputId = null;
    audioDeviceWarning = null;
    audioProcessing = const AudioProcessingPreferences();
    profile = null;
    profileLoadError = null;
    await _nativeNotifications.useAccount(null);
    topology = null;
    selectedChannel = null;
    voiceRosters = null;
    voiceRosterError = null;
  }

  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) => _session.authenticate(login, password, register: register);

  Future<void> logout() => _session.logout();

  Future<void> _clearSignedOutAccount() async {
    ComposerDraftMemory.clear();
    _textHistoryLoadSequence++;
    loadingMessages = false;
    profile = null;
    profileLoadError = null;
    await _nativeNotifications.useAccount(null);
    _stopVoiceRosterEvents();
    voiceRosters = null;
    voiceRosterError = null;
    _voiceVolumePreferences = null;
    _audioPreferences = null;
    audioActivationMode = AudioActivationMode.vad;
    pushToTalkKeyId = null;
    pushToTalkKeyLabel = null;
    pushToTalkPressed = false;
    audioActivationError = null;
    selectedAudioInputId = null;
    selectedAudioOutputId = null;
    audioDeviceWarning = null;
    audioProcessing = const AudioProcessingPreferences();
    topology = null;
    selectedChannel = null;
    messages = const [];
    _sendRetryIds.clear();
    _pendingTextSends.clear();
    _pendingDirectSends.clear();
    members = const [];
    directMessages = const [];
    directMessageCandidates = const [];
    selectedDirectMessage = null;
    directMessageHistory = const [];
    nextDirectMessageCursor = null;
  }

  Future<void> refreshProfile() async {
    profileLoading = true;
    profileLoadError = null;
    notifyListeners();
    try {
      profile = await api.ownProfile();
    } catch (cause) {
      profileLoadError = _message(cause);
    } finally {
      profileLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshMaintenance() async {
    try {
      final active = await api.maintenanceActive();
      if (maintenanceActive != active) {
        maintenanceActive = active;
        notifyListeners();
      }
    } catch (_) {
      if (maintenanceActive) {
        maintenanceActive = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshVoiceRosters() async {
    if (phase != AppPhase.ready || user == null || _voiceRosterLoading) return;
    _voiceRosterLoading = true;
    final revision = ++_voiceRosterRevision;
    try {
      final rosters = await api.voiceParticipants();
      if (revision != _voiceRosterRevision || phase != AppPhase.ready) return;
      voiceRosters = rosters;
      voiceRosterError = null;
    } catch (cause) {
      if (revision != _voiceRosterRevision || phase != AppPhase.ready) return;
      voiceRosters = null;
      voiceRosterError = _message(cause);
    } finally {
      if (revision == _voiceRosterRevision) {
        _voiceRosterLoading = false;
        notifyListeners();
      }
    }
  }

  void _startVoiceRosterEvents() {
    if (user == null || _voiceRosterWatching) return;
    _voiceRosterWatching = true;
    unawaited(_watchVoiceRosterEvents(++_voiceRosterRevision));
  }

  Future<void> _watchVoiceRosterEvents(int revision) async {
    while (_voiceRosterWatching &&
        revision == _voiceRosterRevision &&
        phase == AppPhase.ready) {
      try {
        final response = await api.voiceRosterEvents();
        if (!_voiceRosterWatching || revision != _voiceRosterRevision) {
          await response.stream.listen(null).cancel();
          return;
        }
        final done = Completer<void>();
        _voiceRosterStreamDone = done;
        _voiceRosterSubscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (revision != _voiceRosterRevision) return;
                try {
                  final rooms = parseVoiceRosterEvent(line);
                  if (rooms == null) return;
                  _voiceRosterStaleTimer?.cancel();
                  _voiceRosterStaleTimer = null;
                  voiceRosters = rooms;
                  voiceRosterError = null;
                  notifyListeners();
                } catch (cause) {
                  voiceRosters = null;
                  voiceRosterError = _message(cause);
                  notifyListeners();
                }
              },
              onError: (Object _) {
                _markVoiceRosterStreamLost(revision);
                if (!done.isCompleted) done.complete();
              },
              onDone: () {
                _markVoiceRosterStreamLost(revision);
                if (!done.isCompleted) done.complete();
              },
            );
        await done.future;
        _voiceRosterSubscription = null;
        _voiceRosterStreamDone = null;
      } catch (cause) {
        if (revision == _voiceRosterRevision) {
          if (cause is ApiFailure &&
              (cause.status == 401 || cause.status == 403)) {
            voiceRosters = null;
          }
          if (voiceRosters == null) {
            voiceRosterError = _message(cause);
          } else {
            _markVoiceRosterStreamLost(revision);
          }
          notifyListeners();
        }
      }
      if (!_voiceRosterWatching || revision != _voiceRosterRevision) return;
      final retry = Completer<void>();
      _voiceRosterRetryDone = retry;
      _voiceRosterRetryTimer = Timer(voiceRosterRetryDelay, () {
        if (!retry.isCompleted) retry.complete();
      });
      await retry.future;
      _voiceRosterRetryTimer = null;
      _voiceRosterRetryDone = null;
    }
  }

  void _markVoiceRosterStreamLost(int revision) {
    if (!_voiceRosterWatching || revision != _voiceRosterRevision) return;
    if (voiceRosters == null && voiceRosterError == null) {
      voiceRosterError = 'Нет связи со списком голосовых каналов.';
      notifyListeners();
    }
    _voiceRosterStaleTimer ??= Timer(voiceRosterStaleTimeout, () {
      _voiceRosterStaleTimer = null;
      if (!_voiceRosterWatching || revision != _voiceRosterRevision) return;
      voiceRosters = null;
      voiceRosterError = 'Нет связи со списком голосовых каналов.';
      notifyListeners();
    });
  }

  void _stopVoiceRosterEvents() {
    _voiceRosterWatching = false;
    _voiceRosterRetryTimer?.cancel();
    _voiceRosterRetryTimer = null;
    _voiceRosterStaleTimer?.cancel();
    _voiceRosterStaleTimer = null;
    final retry = _voiceRosterRetryDone;
    if (retry != null && !retry.isCompleted) retry.complete();
    _voiceRosterRetryDone = null;
    final subscription = _voiceRosterSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    _voiceRosterSubscription = null;
    final done = _voiceRosterStreamDone;
    if (done != null && !done.isCompleted) done.complete();
    _voiceRosterStreamDone = null;
    _voiceRosterRevision++;
    _voiceRosterLoading = false;
  }

  void toggleWorkspacePanel(WorkspacePanel panel) {
    workspacePanel = workspacePanel == panel ? WorkspacePanel.none : panel;
    error = null;
    if (workspacePanel == WorkspacePanel.audio) {
      _audioDevices.watch();
      unawaited(refreshAudioDevices());
    }
    notifyListeners();
  }

  AudioCaptureOptions get _audioCaptureOptions => _audioDevices.captureOptions;

  Future<void> _loadAudioPreferences(String accountId) async {
    final ticket = _session.scope.capture();
    final preferences = await AudioPreferences.open(accountId);
    if (!ticket.isActive || user?.accountId != accountId) return;
    _audioPreferences = preferences;
    if (!preferences.persistent) {
      audioSettingsError = 'Не удалось открыть хранилище настроек аудио.';
    }
    selectedAudioInputId = preferences.inputDeviceId;
    selectedAudioOutputId = preferences.outputDeviceId;
    audioProcessing = preferences.processing;
    audioActivationMode = preferences.activationMode == 'PTT'
        ? AudioActivationMode.ptt
        : AudioActivationMode.vad;
    pushToTalkKeyId = preferences.pttKeyId;
    pushToTalkKeyLabel = preferences.pttKeyLabel;
    audioActivationError =
        audioActivationMode == AudioActivationMode.ptt &&
            pushToTalkKeyId == null
        ? 'Назначьте клавишу для push-to-talk.'
        : null;
  }

  Future<void> refreshAudioDevices() => _audioDevices.refreshAudioDevices();

  void _refreshAudioDevicesAfterMicrophoneCapture() =>
      _audioDevices.refreshAfterMicrophoneCapture();

  Future<void> selectAudioInput(String deviceId) =>
      _audioDevices.selectAudioInput(deviceId);

  Future<void> selectAudioOutput(String deviceId) =>
      _audioDevices.selectAudioOutput(deviceId);

  Future<void> setAudioProcessing(AudioProcessingPreferences next) =>
      _audioDevices.setAudioProcessing(next);

  Future<void> setPushToTalkKey(int? keyId, String? label) async {
    final previousId = pushToTalkKeyId;
    final previousLabel = pushToTalkKeyLabel;
    pushToTalkKeyId = keyId;
    pushToTalkKeyLabel = keyId == null ? null : label;
    audioActivationError = null;
    try {
      await _audioPreferences?.setPttKey(pushToTalkKeyId, pushToTalkKeyLabel);
    } catch (cause) {
      pushToTalkKeyId = previousId;
      pushToTalkKeyLabel = previousLabel;
      audioActivationError =
          'Не удалось сохранить клавишу PTT: ${cause.runtimeType}.';
    }
    notifyListeners();
  }

  Future<void> setAudioActivationMode(AudioActivationMode next) async {
    if (audioActivationMode == next) return;
    final previous = audioActivationMode;
    if (next == AudioActivationMode.ptt) {
      _microphoneMutedBeforePtt = microphoneMuted;
      audioActivationMode = next;
      pushToTalkPressed = false;
      if (pushToTalkKeyId == null) {
        audioActivationError = 'Назначьте клавишу для push-to-talk.';
      } else {
        audioActivationError = null;
      }
      if (_room != null && voicePhase != VoicePhase.leaving) {
        await _applyMicrophoneMuted(true);
      }
    } else {
      pushToTalkPressed = false;
      audioActivationMode = next;
      audioActivationError = null;
      if (_room != null && voicePhase != VoicePhase.leaving) {
        await _applyMicrophoneMuted(
          deafened ? true : _microphoneMutedBeforePtt,
        );
      }
    }
    try {
      await _audioPreferences?.setActivationMode(
        next == AudioActivationMode.ptt ? 'PTT' : 'VAD',
      );
    } catch (cause) {
      audioActivationMode = previous;
      audioActivationError =
          'Не удалось сохранить режим микрофона: ${cause.runtimeType}.';
      if (_room != null) {
        await _applyMicrophoneMuted(
          previous == AudioActivationMode.ptt
              ? !pushToTalkPressed || deafened
              : deafened || _microphoneMutedBeforePtt,
        );
      }
    }
    notifyListeners();
  }

  Future<void> setPushToTalkPressed(bool pressed) async {
    if (audioActivationMode != AudioActivationMode.ptt ||
        pushToTalkPressed == pressed) {
      return;
    }
    if (pressed &&
        voicePhase != VoicePhase.connected &&
        voicePhase != VoicePhase.listener) {
      return;
    }
    pushToTalkPressed = pressed;
    audioActivationError = null;
    if (voicePhase == VoicePhase.reconnecting) {
      microphoneMuted = true;
      notifyListeners();
      return;
    }
    if (_room == null) {
      notifyListeners();
      return;
    }
    final shouldMute = !pressed || deafened;
    final success = await _applyMicrophoneMuted(shouldMute);
    if (!success) {
      pushToTalkPressed = false;
      await _applyMicrophoneMuted(true);
    } else if (pressed && !shouldMute) {
      _listenerOnly = false;
      if (voicePhase == VoicePhase.listener) voicePhase = VoicePhase.connected;
    }
    notifyListeners();
  }

  Future<bool> _applyMicrophoneMuted(bool muted) async {
    final participant = _room?.localParticipant;
    if (participant == null) {
      microphoneMuted = muted;
      return true;
    }
    try {
      await participant.setMicrophoneEnabled(
        !muted,
        audioCaptureOptions: _audioCaptureOptions,
      );
      microphoneMuted = muted;
      if (!muted) {
        _refreshAudioDevicesAfterMicrophoneCapture();
        microphoneUnavailable = false;
      }
      return true;
    } catch (cause) {
      microphoneMuted = true;
      if (!muted) microphoneUnavailable = true;
      audioActivationError = 'Не удалось изменить микрофон: ${_message(cause)}';
      return false;
    }
  }

  Future<bool> saveDisplayName(String value) async {
    if (value.runes.isEmpty || value.runes.length > 64) {
      error = 'Имя должно содержать от 1 до 64 символов.';
      notifyListeners();
      return false;
    }
    profileSaving = true;
    error = null;
    notifyListeners();
    try {
      profile = await api.updateOwnProfile(value);
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
        current.runes.length > 128 ||
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

  Future<bool> uploadAvatar(Uint8List bytes, String contentType) async {
    if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      error = 'Выберите изображение размером не более 2 МиБ.';
      notifyListeners();
      return false;
    }
    profileSaving = true;
    error = null;
    notifyListeners();
    try {
      await api.uploadOwnAvatar(bytes, contentType);
      profile = await api.ownProfile();
      avatarRevision++;
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

  Future<bool> deleteAvatar() async {
    profileSaving = true;
    error = null;
    notifyListeners();
    try {
      await api.deleteOwnAvatar();
      profile = await api.ownProfile();
      avatarRevision++;
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

  Future<void> refreshMembers() async {
    membersLoading = true;
    membersError = null;
    notifyListeners();
    try {
      members = await api.members();
    } catch (cause) {
      membersError = _message(cause);
    } finally {
      membersLoading = false;
      notifyListeners();
    }
  }

  MemberPresence memberPresence(GuildMember member) =>
      guildPresence.resolve(member.id, member.presence);

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
    _textHistoryLoadSequence++;
    loadingMessages = false;
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

  void openSearchPanel() {
    _searchContextSequence++;
    _searchOriginChannel = selectedChannel;
    _searchOriginDirectMessage = selectedDirectMessage;
    searchContextMessage = null;
    searchContextHeading = 'Контекст найденного сообщения';
    searchContextTextMessages = const [];
    searchContextDirectMessages = const [];
    searchContextError = null;
    workspacePanel = WorkspacePanel.search;
    notifyListeners();
  }

  void closeSearchPanel() {
    _searchContextSequence++;
    loadingSearchContext = false;
    searchContextHeading = 'Контекст найденного сообщения';
    if (workspacePanel == WorkspacePanel.search) {
      workspacePanel = WorkspacePanel.none;
    }
    _searchOriginChannel = null;
    _searchOriginDirectMessage = null;
    notifyListeners();
  }

  Future<void> openSearchContext(
    SearchMessage target, {
    String? heading,
  }) async {
    final sequence = ++_searchContextSequence;
    searchContextMessage = target;
    searchContextHeading = heading ?? 'Контекст найденного сообщения';
    searchContextTextMessages = const [];
    searchContextDirectMessages = const [];
    searchContextError = null;
    loadingSearchContext = true;
    workspacePanel = WorkspacePanel.searchContext;
    if (target.kind == SearchMessageKind.channel) {
      final channel = topology?.categories
          .expand((category) => category.channels)
          .where(
            (value) =>
                value.id == target.conversationId &&
                value.kind == ChannelKind.text,
          )
          .firstOrNull;
      var resolvedChannel = channel;
      if (resolvedChannel == null) {
        await refreshTopology();
        if (sequence != _searchContextSequence) return;
        resolvedChannel = topology?.categories
            .expand((category) => category.channels)
            .where(
              (value) =>
                  value.id == target.conversationId &&
                  value.kind == ChannelKind.text,
            )
            .firstOrNull;
      }
      if (resolvedChannel == null) {
        searchContextError = 'Найденный канал больше недоступен.';
        loadingSearchContext = false;
        notifyListeners();
        return;
      }
      _textHistoryLoadSequence++;
      loadingMessages = false;
      selectedChannel = resolvedChannel;
      selectedDirectMessage = null;
      navigationSection = NavigationSection.channels;
    } else {
      var conversation = directMessages
          .where((value) => value.id == target.conversationId)
          .firstOrNull;
      if (conversation == null) {
        await refreshDirectMessages();
        if (sequence != _searchContextSequence) return;
        conversation = directMessages
            .where((value) => value.id == target.conversationId)
            .firstOrNull;
      }
      if (conversation == null) {
        searchContextError = 'Личный диалог больше недоступен.';
        loadingSearchContext = false;
        notifyListeners();
        return;
      }
      _textHistoryLoadSequence++;
      loadingMessages = false;
      selectedDirectMessage = conversation;
      selectedChannel = null;
      navigationSection = NavigationSection.directMessages;
    }
    notifyListeners();
    try {
      if (target.kind == SearchMessageKind.channel) {
        final page = await api.messagePage(
          target.conversationId,
          at: target.id,
        );
        if (sequence != _searchContextSequence) return;
        searchContextTextMessages = page.messages;
        if (!page.messages.any((message) => message.id == target.id)) {
          searchContextError =
              'Найденное сообщение больше недоступно в канале.';
        }
      } else {
        final page = await api.directMessageHistoryPage(
          target.conversationId,
          at: target.id,
        );
        if (sequence != _searchContextSequence) return;
        searchContextDirectMessages = page.messages;
        if (!page.messages.any((message) => message.id == target.id)) {
          searchContextError =
              'Найденное сообщение больше недоступно в диалоге.';
        }
      }
    } catch (cause) {
      if (sequence != _searchContextSequence) return;
      searchContextError = _message(cause);
    } finally {
      if (sequence == _searchContextSequence) {
        loadingSearchContext = false;
        notifyListeners();
      }
    }
  }

  Future<void> returnFromSearchContext() async {
    _searchContextSequence++;
    final channel = _searchOriginChannel;
    final directMessage = _searchOriginDirectMessage;
    _searchOriginChannel = null;
    _searchOriginDirectMessage = null;
    searchContextMessage = null;
    searchContextHeading = 'Контекст найденного сообщения';
    searchContextTextMessages = const [];
    searchContextDirectMessages = const [];
    searchContextError = null;
    workspacePanel = WorkspacePanel.none;
    if (channel != null) {
      await selectChannel(channel);
    } else if (directMessage != null) {
      await openDirectConversation(directMessage);
    } else {
      notifyListeners();
    }
  }

  Future<void> openDirectConversation(DirectConversation conversation) async {
    _textHistoryLoadSequence++;
    loadingMessages = false;
    selectedDirectMessage = conversation;
    selectedChannel = null;
    nextDirectMessageCursor = null;
    loadingDirectMessages = true;
    error = null;
    notifyListeners();
    try {
      final page = await api.directMessageHistoryPage(conversation.id);
      if (selectedDirectMessage?.id == conversation.id) {
        _acknowledgeMessageIds(
          page.messages.map((message) => message.clientMessageId),
        );
        directMessageHistory = _withPendingDirect(
          conversation.id,
          page.messages,
        );
        nextDirectMessageCursor = page.nextCursor;
      }
    } catch (cause) {
      error = _message(cause);
    } finally {
      loadingDirectMessages = false;
      notifyListeners();
    }
  }

  Future<bool> loadOlderDirectMessages() async {
    final conversation = selectedDirectMessage;
    final cursor = nextDirectMessageCursor;
    if (conversation == null || cursor == null || loadingOlderDirectMessages) {
      return false;
    }
    loadingOlderDirectMessages = true;
    notifyListeners();
    try {
      final page = await api.directMessageHistoryPage(
        conversation.id,
        before: cursor,
      );
      if (selectedDirectMessage?.id != conversation.id) return false;
      final byId = {
        for (final message in directMessageHistory) message.id: message,
      };
      for (final message in page.messages) {
        byId.putIfAbsent(message.id, () => message);
      }
      _acknowledgeMessageIds(
        page.messages.map((message) => message.clientMessageId),
      );
      directMessageHistory = _withPendingDirect(conversation.id, byId.values);
      nextDirectMessageCursor = page.nextCursor;
      return true;
    } catch (cause) {
      error = _message(cause);
      return false;
    } finally {
      loadingOlderDirectMessages = false;
      notifyListeners();
    }
  }

  Future<void> markSelectedDirectMessageRead() async {
    final conversation = selectedDirectMessage;
    if (conversation == null || loadingDirectMessages) return;
    final visibleOtherMessages = directMessageHistory
        .where(
          (message) =>
              message.sendStatus == null && message.authorId != user?.accountId,
        )
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

  Future<bool> sendDirect(
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<MessageAttachment> attachments = const [],
  }) async {
    final conversation = selectedDirectMessage;
    final trimmed = body.trim();
    if (conversation == null ||
        sending ||
        trimmed.isEmpty && attachments.isEmpty ||
        trimmed.runes.length > 8000) {
      return false;
    }
    final mentions = mentionUserIds.take(100).toSet().toList();
    final attachmentIds = attachments.map((item) => item.id).toList();
    final retryKey = _sendRetryKey(
      'dm',
      conversation.id,
      trimmed,
      replyToId,
      mentions,
      attachmentIds,
    );
    final clientMessageId = _sendRetryIds.putIfAbsent(retryKey, _uuid.v4);
    final pending =
        _pendingDirectSends[clientMessageId] ??
        DirectChatMessage(
          id: 'optimistic:$clientMessageId',
          directMessageId: conversation.id,
          authorId: user?.accountId ?? '',
          body: trimmed,
          createdAt: DateTime.now(),
          deleted: false,
          revision: 0,
          clientMessageId: clientMessageId,
          mentionUserIds: mentions,
          replyToId: replyToId,
          attachments: attachments,
        );
    _pendingDirectSends[clientMessageId] = pending.withSendStatus(
      MessageSendStatus.sending,
    );
    if (selectedDirectMessage?.id == conversation.id) {
      directMessageHistory = _withPendingDirect(
        conversation.id,
        directMessageHistory,
      );
    }
    sending = true;
    error = null;
    notifyListeners();
    try {
      final message = await api.sendDirectMessage(
        conversation.id,
        clientMessageId,
        trimmed,
        replyToId: replyToId,
        mentionUserIds: mentions,
        attachmentIds: attachmentIds,
      );
      _sendRetryIds.remove(retryKey);
      _pendingDirectSends.remove(clientMessageId);
      if (phase == AppPhase.ready &&
          selectedDirectMessage?.id == conversation.id) {
        directMessageHistory = [
          ...directMessageHistory.where(
            (value) =>
                value.id != message.id &&
                value.clientMessageId != clientMessageId,
          ),
          message,
        ];
      }
      return true;
    } catch (cause) {
      if (_pendingDirectSends.containsKey(clientMessageId)) {
        _pendingDirectSends[clientMessageId] = pending.withSendStatus(
          MessageSendStatus.failed,
        );
        if (selectedDirectMessage?.id == conversation.id) {
          directMessageHistory = _withPendingDirect(
            conversation.id,
            directMessageHistory,
          );
        }
      }
      if (phase == AppPhase.ready &&
          selectedDirectMessage?.id == conversation.id) {
        error = _message(cause);
      }
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<MessageAttachment> uploadAttachment(
    String fileName,
    Uint8List bytes, {
    String? channelId,
    String? directMessageId,
    void Function(int sent, int total)? onProgress,
  }) async {
    if ((channelId == null) == (directMessageId == null)) {
      throw const ApiFailure('Выберите беседу для вложения.');
    }
    if (directMessageId != null) {
      return api.uploadDirectMessageAttachment(
        directMessageId,
        fileName,
        bytes,
        onProgress: onProgress,
      );
    }
    return api.uploadChannelAttachment(
      channelId!,
      fileName,
      bytes,
      onProgress: onProgress,
    );
  }

  Future<bool> editDirect(DirectChatMessage message, String body) async =>
      (await editDirectWithResult(message, body, message.revision)).kind ==
      MessageEditStatus.saved;

  Future<MessageEditOutcome> editDirectWithResult(
    DirectChatMessage message,
    String body,
    int expectedRevision, {
    List<String>? mentionUserIds,
  }) async {
    final trimmed = body.trim();
    if (selectedDirectMessage?.id != message.directMessageId ||
        !directMessageHistory.any((item) => item.id == message.id)) {
      return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
    }
    if (trimmed.isEmpty || trimmed.runes.length > 8000) {
      return (
        kind: MessageEditStatus.error,
        message: 'Сообщение должно содержать до 8000 символов.',
      );
    }
    try {
      final edited = await api.editDirectMessage(
        message.directMessageId,
        message.id,
        trimmed,
        expectedRevision,
        mentionUserIds: mentionUserIds ?? message.mentionUserIds,
      );
      if (selectedDirectMessage?.id != message.directMessageId) {
        return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
      }
      directMessageHistory = directMessageHistory
          .map((value) => value.id == edited.id ? edited : value)
          .toList(growable: false);
      error = null;
      notifyListeners();
      return (kind: MessageEditStatus.saved, message: null);
    } catch (cause) {
      final conflict = cause is ApiFailure && cause.status == 409;
      final messageText = conflict
          ? 'Сообщение изменилось. Обновите версию, чтобы сохранить свой текст.'
          : _message(cause);
      if (selectedDirectMessage?.id == message.directMessageId) {
        error = messageText;
        notifyListeners();
      }
      return (
        kind: conflict ? MessageEditStatus.conflict : MessageEditStatus.error,
        message: messageText,
      );
    }
  }

  Future<DirectChatMessage?> refreshDirectMessageRevision(
    DirectChatMessage message,
  ) async {
    final target = message.directMessageId;
    if (selectedDirectMessage?.id != target ||
        !directMessageHistory.any((item) => item.id == message.id)) {
      return null;
    }
    final count = directMessageHistory
        .where((item) => item.sendStatus == null)
        .length;
    final maxPages = (count + 49) ~/ 50 + 2;
    final seen = <String>{};
    String? before;
    try {
      for (var pageIndex = 0; pageIndex < maxPages; pageIndex++) {
        final page = await api.directMessageHistoryPage(target, before: before);
        if (selectedDirectMessage?.id != target) return null;
        final found = page.messages
            .where((item) => item.id == message.id)
            .firstOrNull;
        if (found != null) {
          directMessageHistory = directMessageHistory
              .map(
                (item) => item.id == found.id && found.revision >= item.revision
                    ? found
                    : item,
              )
              .toList(growable: false);
          error = null;
          notifyListeners();
          return directMessageHistory
              .where((item) => item.id == found.id)
              .firstOrNull;
        }
        final cursor = page.nextCursor;
        if (cursor == null || !seen.add(cursor)) break;
        before = cursor;
      }
    } catch (cause) {
      if (selectedDirectMessage?.id == target) {
        error = _message(cause);
        notifyListeners();
      }
    }
    return null;
  }

  Future<void> deleteDirect(DirectChatMessage message) async {
    try {
      await api.deleteDirectMessage(message.directMessageId, message.id);
      if (selectedDirectMessage?.id == message.directMessageId) {
        directMessageHistory = directMessageHistory
            .map(
              (item) => item.id == message.id && !item.deleted
                  ? item.asDeleted()
                  : item,
            )
            .toList(growable: false);
        error = null;
        notifyListeners();
      }
    } catch (cause) {
      if (selectedDirectMessage?.id == message.directMessageId) {
        error = _message(cause);
        notifyListeners();
      }
    }
  }

  Future<void> refreshTopology() async {
    try {
      topology = await api.topology();
      final all = topology!.categories.expand((category) => category.channels);
      if (selectedChannel != null &&
          !all.any((channel) => channel.id == selectedChannel!.id)) {
        _textHistoryLoadSequence++;
        selectedChannel = null;
        messages = const [];
        nextMessageCursor = null;
        loadingMessages = false;
      }
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
    final loadSequence = ++_textHistoryLoadSequence;
    workspacePanel = WorkspacePanel.none;
    navigationSection = NavigationSection.channels;
    selectedDirectMessage = null;
    selectedChannel = channel;
    messages = const [];
    nextMessageCursor = null;
    _textHistoryHasLoadedOlderPages = false;
    loadingMessages = false;
    error = null;
    notifyListeners();
    if (channel.kind == ChannelKind.text) {
      loadingMessages = true;
      notifyListeners();
      try {
        final page = await api.messagePage(channel.id);
        if (_textHistoryLoadSequence == loadSequence &&
            selectedChannel?.id == channel.id) {
          _acknowledgeMessageIds(
            page.messages.map((message) => message.clientMessageId),
          );
          messages = _withPendingText(channel.id, page.messages);
          nextMessageCursor = page.nextCursor;
        }
      } catch (cause) {
        if (_textHistoryLoadSequence == loadSequence &&
            selectedChannel?.id == channel.id) {
          error = _message(cause);
        }
      } finally {
        if (_textHistoryLoadSequence == loadSequence) {
          loadingMessages = false;
          notifyListeners();
        }
      }
    }
  }

  Future<void> enterVoiceChannel(GuildChannel channel) async {
    await selectChannel(channel);
    if (channel.kind != ChannelKind.voice || channel.admissionClosed) return;
    if (voiceChannel?.id == channel.id || voicePhase == VoicePhase.joining) {
      return;
    }
    if (voiceChannel != null) await leaveVoice();
    await joinVoice(channel);
  }

  Future<bool> loadOlderMessages() async {
    final channel = selectedChannel;
    final cursor = nextMessageCursor;
    if (channel == null ||
        channel.kind != ChannelKind.text ||
        cursor == null ||
        loadingOlderMessages) {
      return false;
    }
    loadingOlderMessages = true;
    notifyListeners();
    try {
      final page = await api.messagePage(channel.id, before: cursor);
      if (selectedChannel?.id != channel.id) return false;
      _textHistoryHasLoadedOlderPages = true;
      final byId = {for (final message in messages) message.id: message};
      for (final message in page.messages) {
        byId.putIfAbsent(message.id, () => message);
      }
      _acknowledgeMessageIds(
        page.messages.map((message) => message.clientMessageId),
      );
      messages = _withPendingText(channel.id, byId.values);
      nextMessageCursor = page.nextCursor;
      return true;
    } catch (cause) {
      error = _message(cause);
      return false;
    } finally {
      loadingOlderMessages = false;
      notifyListeners();
    }
  }

  /// Refreshes the newest page without discarding history already loaded by
  /// the user. This is used for realtime message events and resynchronization.
  Future<void> refreshSelectedTextHistory() async {
    final channel = selectedChannel;
    if (channel == null || channel.kind != ChannelKind.text) return;

    final loadSequence = ++_textHistoryLoadSequence;
    loadingMessages = true;
    notifyListeners();
    try {
      final page = await api.messagePage(channel.id);
      if (_textHistoryLoadSequence != loadSequence ||
          selectedChannel?.id != channel.id) {
        return;
      }

      final byId = {for (final message in messages) message.id: message};
      for (final message in page.messages) {
        final existing = byId[message.id];
        if (existing == null || message.revision >= existing.revision) {
          byId[message.id] = message;
        }
      }
      _acknowledgeMessageIds(
        page.messages.map((message) => message.clientMessageId),
      );
      messages = _withPendingText(channel.id, byId.values);
      if (!_textHistoryHasLoadedOlderPages) {
        nextMessageCursor = page.nextCursor;
      }
      error = null;
    } catch (cause) {
      if (_textHistoryLoadSequence == loadSequence &&
          selectedChannel?.id == channel.id) {
        error = _message(cause);
      }
    } finally {
      if (_textHistoryLoadSequence == loadSequence &&
          selectedChannel?.id == channel.id) {
        loadingMessages = false;
        notifyListeners();
      }
    }
  }

  Future<void> markTextChannelRead(String channelId, String messageId) async {
    if (phase != AppPhase.ready ||
        selectedChannel?.id != channelId ||
        selectedChannel?.kind != ChannelKind.text) {
      return;
    }
    final message = messages
        .where(
          (candidate) =>
              candidate.id == messageId &&
              !candidate.deleted &&
              candidate.sendStatus == null,
        )
        .firstOrNull;
    if (message == null) return;
    final lastReadAt = _lastReadTextAt[channelId];
    if (lastReadAt != null && !message.createdAt.isAfter(lastReadAt)) return;
    final pendingAt = _pendingTextReadAt[channelId];
    if (pendingAt != null && !message.createdAt.isAfter(pendingAt)) return;
    final key = '$channelId:$messageId';
    if (!_pendingTextReads.add(key)) return;
    _pendingTextReadAt[channelId] = message.createdAt;
    try {
      await api.advanceTextChannelReadCursor(channelId, messageId);
      _lastReadTextAt[channelId] = message.createdAt;
      if (phase != AppPhase.ready || selectedChannel?.id != channelId) return;
      final updated = await api.topology();
      if (phase != AppPhase.ready || selectedChannel?.id != channelId) return;
      topology = updated;
      selectedChannel = updated.categories
          .expand((category) => category.channels)
          .where((channel) => channel.id == channelId)
          .firstOrNull;
      notifyListeners();
    } catch (_) {
      // Keep server-provided counts until a visible retry succeeds.
    } finally {
      _pendingTextReads.remove(key);
      if (_pendingTextReadAt[channelId] == message.createdAt) {
        _pendingTextReadAt.remove(channelId);
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
          guildPresence.acceptSnapshot(payload['online_user_ids']);
        case 'presence.changed':
          guildPresence.acceptChange(payload['user_id'], payload['presence']);
        case 'message.created':
          final previousUnread = _addressedUnreadCount(kind!, payload);
          if (selectedChannel?.id == payload['channel_id']) {
            unawaited(refreshSelectedTextHistory());
          }
          unawaited(
            _refreshAndDeliverMessageNotification(
              eventId: eventId,
              kind: kind,
              payload: payload,
              previousUnread: previousUnread,
            ),
          );
        case 'direct_message.message_created':
          final previousUnread = _addressedUnreadCount(kind!, payload) ?? 0;
          unawaited(
            _refreshAndDeliverMessageNotification(
              eventId: eventId,
              kind: kind,
              payload: payload,
              previousUnread: previousUnread,
            ),
          );
        case 'channel.updated':
          unawaited(refreshTopology());
        case 'connection.resync_required':
          unawaited(refreshTopology());
          unawaited(refreshMembers());
          if (selectedChannel?.kind == ChannelKind.text) {
            unawaited(refreshSelectedTextHistory());
          }
        case 'voice.lease_revoked':
          final revocation = VoiceLeaseRevocation.parse(
            payload['lease_id'],
            payload['reason'],
            activeLeaseId: _leaseId,
            admissionPending: _voiceAdmissionPending,
          );
          if (revocation != null) {
            if (_voiceAdmissionPending) {
              _revokedVoiceLeasesDuringJoin[revocation.leaseId] =
                  revocation.reason;
              if (_revokedVoiceLeasesDuringJoin.length > 16) {
                _revokedVoiceLeasesDuringJoin.remove(
                  _revokedVoiceLeasesDuringJoin.keys.first,
                );
              }
            } else {
              unawaited(
                _handleVoiceLeaseRevoked(revocation.leaseId, revocation.reason),
              );
            }
          }
      }
      notifyListeners();
    } catch (_) {
      // Unknown or malformed future events are ignored and grant no authority.
    }
  }

  int? _addressedUnreadCount(String? kind, Map<String, dynamic> payload) {
    if (kind == 'direct_message.message_created') {
      final id = payload['direct_message_id'];
      if (id is! String) return null;
      return directMessages
          .where((conversation) => conversation.id == id)
          .firstOrNull
          ?.unreadCount;
    }
    if (kind == 'message.created') {
      final id = payload['channel_id'];
      if (id is! String) return null;
      return topology?.categories
          .expand((category) => category.channels)
          .where(
            (channel) => channel.id == id && channel.kind == ChannelKind.text,
          )
          .firstOrNull
          ?.unreadCount;
    }
    return null;
  }

  Future<void> _refreshAndDeliverMessageNotification({
    required String? eventId,
    required String? kind,
    required Map<String, dynamic> payload,
    required int? previousUnread,
  }) async {
    if (eventId == null || kind == null || user == null) return;
    try {
      if (kind == 'message.created') {
        await refreshTopology();
      } else if (kind == 'direct_message.message_created') {
        await refreshDirectMessages();
      }
      final body = notificationBodyForUnreadIncrease(
        kind: kind,
        previousUnread: previousUnread,
        currentUnread:
            _addressedUnreadCount(kind, payload) ??
            (kind == 'direct_message.message_created' ? 0 : null),
      );
      if (body == null) return;
      await _nativeNotifications.deliver(
        eventId: eventId,
        body: body,
        appIsForeground: _notificationAppIsForeground,
      );
      if (_nativeNotifications.error != null) notifyListeners();
    } catch (_) {
      // Native alerts must not interfere with message or realtime recovery.
    }
  }

  Future<void> _handleVoiceLeaseRevoked(String leaseId, String reason) async {
    if (_leaseId != leaseId || _room == null) return;
    _clearVoiceStreamNotice(resetTracker: true, notify: false);
    _stopVoiceConnectionStatsPolling();
    _stopScreenShareMetrics();
    voicePhase = VoicePhase.leaving;
    notifyListeners();
    try {
      await _room?.disconnect();
    } catch (_) {}
    await _disposeVoiceEvents();
    _room = null;
    _voicePingMs = null;
    _leaseId = null;
    voiceChannel = null;
    _mutedScreenShareAudioIdentities.clear();
    voicePhase = VoicePhase.error;
    microphoneMuted = false;
    microphoneUnavailable = false;
    deafened = false;
    pushToTalkPressed = false;
    _listenerOnly = false;
    error = VoiceLeaseRevocation(leaseId: leaseId, reason: reason).message;
    notifyListeners();
  }

  void _handleRealtimeClosed() {
    _realtimeSocket = null;
    realtimeConnected = false;
    guildPresence.invalidate();
    notifyListeners();
    unawaited(_checkSessionAfterRealtimeClose());
  }

  Future<void> _checkSessionAfterRealtimeClose() async {
    if (phase != AppPhase.ready || _checkingRealtimeSession) return;
    _checkingRealtimeSession = true;
    try {
      if (await api.currentSession() == null) {
        await _expireSession();
        return;
      }
    } catch (_) {
      // A transient REST failure does not establish that the session expired.
    } finally {
      _checkingRealtimeSession = false;
    }
    _scheduleRealtimeRetry();
  }

  void _scheduleRealtimeRetry() {
    if (phase != AppPhase.ready || _realtimeRetry != null) return;
    guildPresence.invalidate();
    notifyListeners();
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
    guildPresence.invalidate();
  }

  @override
  void dispose() {
    _session.dispose();
    _closeScreenPreviewSubscriptions();
    _realtimeRetry?.cancel();
    _maintenanceTimer?.cancel();
    _stopVoiceRosterEvents();
    _voiceStreamNoticeTimer?.cancel();
    _stopVoiceConnectionStatsPolling();
    _stopScreenShareMetrics();
    _audioDevices.dispose();
    api.onUnauthorized = null;
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_realtimeSocket?.close());
    unawaited(_room?.disconnect());
    super.dispose();
  }

  Future<bool> send(
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<MessageAttachment> attachments = const [],
  }) async {
    final channel = selectedChannel;
    final trimmed = body.trim();
    if (channel == null ||
        channel.kind != ChannelKind.text ||
        sending ||
        trimmed.isEmpty && attachments.isEmpty ||
        trimmed.runes.length > 8000) {
      return false;
    }
    final mentions = mentionUserIds.take(100).toSet().toList();
    final attachmentIds = attachments.map((item) => item.id).toList();
    final retryKey = _sendRetryKey(
      'text',
      channel.id,
      trimmed,
      replyToId,
      mentions,
      attachmentIds,
    );
    final clientMessageId = _sendRetryIds.putIfAbsent(retryKey, _uuid.v4);
    final pending =
        _pendingTextSends[clientMessageId] ??
        ChatMessage(
          id: 'optimistic:$clientMessageId',
          channelId: channel.id,
          authorId: user?.accountId ?? '',
          body: trimmed,
          createdAt: DateTime.now(),
          deleted: false,
          revision: 0,
          clientMessageId: clientMessageId,
          replyToId: replyToId,
          mentionUserIds: mentions,
          attachments: attachments,
        );
    _pendingTextSends[clientMessageId] = pending.withSendStatus(
      MessageSendStatus.sending,
    );
    messages = _withPendingText(channel.id, messages);
    sending = true;
    error = null;
    notifyListeners();
    try {
      final message = await api.sendMessage(
        channel.id,
        clientMessageId,
        trimmed,
        replyToId: replyToId,
        mentionUserIds: mentions,
        attachmentIds: attachmentIds,
      );
      _sendRetryIds.remove(retryKey);
      _pendingTextSends.remove(clientMessageId);
      if (phase == AppPhase.ready && selectedChannel?.id == channel.id) {
        messages = [
          ...messages.where(
            (value) =>
                value.id != message.id &&
                value.clientMessageId != clientMessageId,
          ),
          message,
        ];
      }
      return true;
    } catch (cause) {
      if (_pendingTextSends.containsKey(clientMessageId)) {
        _pendingTextSends[clientMessageId] = pending.withSendStatus(
          MessageSendStatus.failed,
        );
        if (selectedChannel?.id == channel.id) {
          messages = _withPendingText(channel.id, messages);
        }
      }
      if (phase == AppPhase.ready && selectedChannel?.id == channel.id) {
        error = _message(cause);
      }
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  String _sendRetryKey(
    String kind,
    String conversationId,
    String body,
    String? replyToId,
    List<String> mentions,
    List<String> attachmentIds,
  ) => jsonEncode([
    kind,
    conversationId,
    body,
    replyToId,
    mentions,
    attachmentIds,
  ]);

  void _acknowledgeMessageIds(Iterable<String?> ids) {
    final acknowledged = ids.whereType<String>().toSet();
    if (acknowledged.isEmpty) return;
    _sendRetryIds.removeWhere((_, id) => acknowledged.contains(id));
    for (final id in acknowledged) {
      _pendingTextSends.remove(id);
      _pendingDirectSends.remove(id);
    }
  }

  List<ChatMessage> _withPendingText(
    String channelId,
    Iterable<ChatMessage> history,
  ) {
    final confirmed = history
        .where((message) => message.sendStatus == null)
        .toList();
    final confirmedIds = confirmed
        .map((message) => message.clientMessageId)
        .toSet();
    final combined = [
      ...confirmed,
      ..._pendingTextSends.values.where(
        (message) =>
            message.channelId == channelId &&
            !confirmedIds.contains(message.clientMessageId),
      ),
    ];
    combined.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return combined;
  }

  List<DirectChatMessage> _withPendingDirect(
    String conversationId,
    Iterable<DirectChatMessage> history,
  ) {
    final confirmed = history
        .where((message) => message.sendStatus == null)
        .toList();
    final confirmedIds = confirmed
        .map((message) => message.clientMessageId)
        .toSet();
    final combined = [
      ...confirmed,
      ..._pendingDirectSends.values.where(
        (message) =>
            message.directMessageId == conversationId &&
            !confirmedIds.contains(message.clientMessageId),
      ),
    ];
    combined.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return combined;
  }

  Future<bool> retryTextSend(String clientMessageId) async {
    final pending = _pendingTextSends[clientMessageId];
    if (pending == null ||
        pending.sendStatus != MessageSendStatus.failed ||
        selectedChannel?.id != pending.channelId) {
      return false;
    }
    return send(
      pending.body,
      replyToId: pending.replyToId,
      mentionUserIds: pending.mentionUserIds,
      attachments: pending.attachments,
    );
  }

  Future<bool> retryDirectSend(String clientMessageId) async {
    final pending = _pendingDirectSends[clientMessageId];
    if (pending == null ||
        pending.sendStatus != MessageSendStatus.failed ||
        selectedDirectMessage?.id != pending.directMessageId) {
      return false;
    }
    return sendDirect(
      pending.body,
      replyToId: pending.replyToId,
      mentionUserIds: pending.mentionUserIds,
      attachments: pending.attachments,
    );
  }

  Future<bool> editText(ChatMessage message, String body) async =>
      (await editTextWithResult(message, body, message.revision)).kind ==
      MessageEditStatus.saved;

  Future<MessageEditOutcome> editTextWithResult(
    ChatMessage message,
    String body,
    int expectedRevision, {
    List<String>? mentionUserIds,
  }) async {
    final trimmed = body.trim();
    if (selectedChannel?.id != message.channelId ||
        !messages.any((item) => item.id == message.id)) {
      return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
    }
    if (trimmed.isEmpty || trimmed.runes.length > 8000) {
      return (
        kind: MessageEditStatus.error,
        message: 'Сообщение должно содержать до 8000 символов.',
      );
    }
    try {
      final edited = await api.editMessage(
        message.channelId,
        message.id,
        trimmed,
        expectedRevision,
        mentionUserIds: mentionUserIds ?? message.mentionUserIds,
      );
      if (selectedChannel?.id != message.channelId) {
        return (kind: MessageEditStatus.stale, message: 'Беседа изменилась.');
      }
      messages = messages
          .map((value) => value.id == edited.id ? edited : value)
          .toList(growable: false);
      error = null;
      notifyListeners();
      return (kind: MessageEditStatus.saved, message: null);
    } catch (cause) {
      final conflict = cause is ApiFailure && cause.status == 409;
      final messageText = conflict
          ? 'Сообщение изменилось. Обновите версию, чтобы сохранить свой текст.'
          : _message(cause);
      if (selectedChannel?.id == message.channelId) {
        error = messageText;
        notifyListeners();
      }
      return (
        kind: conflict ? MessageEditStatus.conflict : MessageEditStatus.error,
        message: messageText,
      );
    }
  }

  Future<ChatMessage?> refreshTextMessageRevision(ChatMessage message) async {
    final target = message.channelId;
    if (selectedChannel?.id != target ||
        !messages.any((item) => item.id == message.id)) {
      return null;
    }
    final count = messages.where((item) => item.sendStatus == null).length;
    final maxPages = (count + 49) ~/ 50 + 2;
    final seen = <String>{};
    String? before;
    try {
      for (var pageIndex = 0; pageIndex < maxPages; pageIndex++) {
        final page = await api.messagePage(target, before: before);
        if (selectedChannel?.id != target) return null;
        final found = page.messages
            .where((item) => item.id == message.id)
            .firstOrNull;
        if (found != null) {
          messages = messages
              .map(
                (item) => item.id == found.id && found.revision >= item.revision
                    ? found
                    : item,
              )
              .toList(growable: false);
          error = null;
          notifyListeners();
          return messages.where((item) => item.id == found.id).firstOrNull;
        }
        final cursor = page.nextCursor;
        if (cursor == null || !seen.add(cursor)) break;
        before = cursor;
      }
    } catch (cause) {
      if (selectedChannel?.id == target) {
        error = _message(cause);
        notifyListeners();
      }
    }
    return null;
  }

  Future<void> deleteText(ChatMessage message) async {
    try {
      await api.deleteMessage(message.channelId, message.id);
      if (selectedChannel?.id == message.channelId) {
        messages = messages
            .map(
              (item) => item.id == message.id && !item.deleted
                  ? item.asDeleted()
                  : item,
            )
            .toList(growable: false);
        error = null;
        notifyListeners();
      }
    } catch (cause) {
      if (selectedChannel?.id == message.channelId) {
        error = _message(cause);
        notifyListeners();
      }
    }
  }

  Future<void> selectRemoteScreenForViewing(String? participantIdentity) async {
    final nextIdentity = participantIdentity?.trim();
    final next = nextIdentity == null || nextIdentity.isEmpty
        ? null
        : nextIdentity;
    final previous = _selectedRemoteScreenViewerIdentity;
    if (previous == next) return;
    _selectedRemoteScreenViewerIdentity = next;
    final room = _room;
    if (room == null) return;

    if (previous != null) {
      final participant = room.remoteParticipants[previous];
      if (participant != null) {
        for (final publication in participant.videoTrackPublications.where(
          (item) => item.source == TrackSource.screenShareVideo,
        )) {
          if (!_screenThumbnailRemoteTrackIds.containsKey(publication.sid)) {
            await _setRemoteTrackSubscription(publication, false);
          }
        }
        for (final publication in participant.audioTrackPublications.where(
          (item) => item.source == TrackSource.screenShareAudio,
        )) {
          await _setRemoteTrackSubscription(publication, false);
        }
      }
    }

    if (next == null ||
        !isCurrentScreenViewerSelection(
          next,
          _selectedRemoteScreenViewerIdentity,
        )) {
      return;
    }
    _subscribeRemoteScreenForViewing(room, next);
  }

  void _subscribeRemoteScreenForViewing(Room room, String identity) {
    final participant = room.remoteParticipants[identity];
    if (participant == null) return;
    for (final publication in participant.videoTrackPublications.where(
      (item) => item.source == TrackSource.screenShareVideo,
    )) {
      unawaited(_setRemoteTrackSubscription(publication, true));
    }
    for (final publication in participant.audioTrackPublications.where(
      (item) => item.source == TrackSource.screenShareAudio,
    )) {
      unawaited(_setRemoteTrackSubscription(publication, true));
    }
  }

  Future<void> _setRemoteTrackSubscription(
    RemoteTrackPublication publication,
    bool subscribed,
  ) async {
    try {
      if (subscribed) {
        await publication.subscribe();
      } else {
        await publication.unsubscribe();
      }
    } catch (_) {
      // Subscription failures leave the screen viewer on its avatar fallback.
    }
  }

  Future<void> joinVoice(
    GuildChannel channel, {
    bool listenerOnly = false,
  }) async {
    if (channel.admissionClosed) return;
    if (voiceChannel?.id == channel.id && _room != null) return;
    screenThumbnails.clear();
    _screenThumbnailRemoteTrackIds.clear();
    _closeScreenPreviewSubscriptions();
    _screenPreviewSubscriptionQueue = ScreenPreviewSubscriptionQueue();
    _selectedRemoteScreenViewerIdentity = null;
    voicePhase = VoicePhase.joining;
    _voicePingMs = null;
    _voiceAdmissionPending = true;
    microphoneUnavailable = false;
    error = null;
    notifyListeners();
    Room? pendingRoom;
    try {
      final (String, VoiceCredential) result = await api.voiceCredential(
        channel.id,
        transfer: true,
      );
      _leaseId = result.$1;
      final revocationDuringAdmission = _revokedVoiceLeasesDuringJoin.remove(
        result.$1,
      );
      if (revocationDuringAdmission != null) {
        _voiceAdmissionPending = false;
        _leaseId = null;
        voicePhase = VoicePhase.error;
        error = VoiceLeaseRevocation(
          leaseId: result.$1,
          reason: revocationDuringAdmission,
        ).message;
        notifyListeners();
        return;
      }
      final room = Room(
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioCaptureOptions: _audioCaptureOptions,
          defaultAudioOutputOptions: AudioOutputOptions(
            deviceId:
                AndroidAudioDevices.isNativeOutputRoute(
                      selectedAudioOutputId,
                    ) ||
                    (AndroidAudioDevices.isAndroid &&
                        selectedAudioOutputId == 'default')
                ? null
                : selectedAudioOutputId,
          ),
        ),
      );
      if (user != null) {
        _voiceVolumePreferences ??= await VoiceVolumePreferences.open(
          user!.accountId,
        );
        if (!_voiceVolumePreferences!.persistent) {
          error =
              'Не удалось загрузить настройки громкости; используется 100%.';
        }
      }
      pendingRoom = room;
      _bindVoiceRoomEvents(room);
      await room.connect(
        result.$2.url,
        result.$2.token,
        connectOptions: const ConnectOptions(autoSubscribe: false),
      );
      if (AndroidAudioDevices.isNativeOutputRoute(selectedAudioOutputId)) {
        if (!await AndroidAudioDevices.selectNativeOutput(
          selectedAudioOutputId!,
        )) {
          throw StateError('Android не смог выбрать сохранённый аудиовыход.');
        }
      }
      final revokedReason = _revokedVoiceLeasesDuringJoin.remove(result.$1);
      if (revokedReason != null) {
        await _finishRevokedVoiceAdmission(room, result.$1, revokedReason);
        notifyListeners();
        return;
      }
      _room = room;
      voiceChannel = channel;
      _subscribeCurrentRemoteVoiceTracks(room);
      await _applySavedVoiceVolumes(room);
      if (listenerOnly) {
        _listenerOnly = true;
        microphoneMuted = true;
        microphoneUnavailable = false;
        voicePhase = VoicePhase.listener;
      } else if (audioActivationMode == AudioActivationMode.ptt) {
        _microphoneMutedBeforePtt = false;
        pushToTalkPressed = false;
        microphoneMuted = true;
        _listenerOnly = false;
        voicePhase = VoicePhase.connected;
      } else {
        try {
          await room.localParticipant?.setMicrophoneEnabled(
            true,
            audioCaptureOptions: _audioCaptureOptions,
          );
          if (room.localParticipant != null) {
            _refreshAudioDevicesAfterMicrophoneCapture();
          }
          microphoneUnavailable = false;
          _listenerOnly = false;
          voicePhase = VoicePhase.connected;
        } catch (_) {
          _listenerOnly = true;
          microphoneMuted = true;
          microphoneUnavailable = true;
          voicePhase = VoicePhase.listener;
        }
      }
      final revokedWhileEnablingMedia = _revokedVoiceLeasesDuringJoin.remove(
        result.$1,
      );
      if (revokedWhileEnablingMedia != null) {
        await _finishRevokedVoiceAdmission(
          room,
          result.$1,
          revokedWhileEnablingMedia,
        );
        notifyListeners();
        return;
      }
      _startVoiceConnectionStatsPolling(room);
      _observeVoiceStreamStarts(room);
      _voiceAdmissionPending = false;
    } catch (cause) {
      _stopVoiceConnectionStatsPolling();
      _voiceAdmissionPending = false;
      if (_leaseId != null) {
        _revokedVoiceLeasesDuringJoin.remove(_leaseId);
      }
      try {
        await pendingRoom?.disconnect();
      } catch (_) {}
      try {
        await AndroidAudioDevices.clearNativeOutput();
      } catch (_) {}
      await _disposeVoiceEvents();
      final leaseId = _leaseId;
      if (leaseId != null) {
        try {
          await api.releaseVoice(leaseId);
        } catch (_) {}
      }
      _room = null;
      _leaseId = null;
      voiceChannel = null;
      _mutedScreenShareAudioIdentities.clear();
      voicePhase = VoicePhase.error;
      error = _message(cause);
    }
    notifyListeners();
  }

  Future<void> _finishRevokedVoiceAdmission(
    Room room,
    String leaseId,
    String reason,
  ) async {
    _clearVoiceStreamNotice(resetTracker: true, notify: false);
    _stopVoiceConnectionStatsPolling();
    _voiceAdmissionPending = false;
    _stopScreenShareMetrics();
    await _disableAndroidScreenShareBackground();
    screenSharePhase = ScreenSharePhase.idle;
    screenShareError = null;
    try {
      await room.disconnect();
    } catch (_) {}
    await _disposeVoiceEvents();
    try {
      await AndroidAudioDevices.clearNativeOutput();
    } catch (_) {}
    if (identical(_room, room)) _room = null;
    if (_leaseId == leaseId) _leaseId = null;
    voiceChannel = null;
    _mutedScreenShareAudioIdentities.clear();
    microphoneMuted = false;
    microphoneUnavailable = false;
    deafened = false;
    pushToTalkPressed = false;
    _listenerOnly = false;
    voicePhase = VoicePhase.error;
    error = VoiceLeaseRevocation(leaseId: leaseId, reason: reason).message;
  }

  void _bindVoiceRoomEvents(Room room) {
    final listener = room.createListener();
    _voiceEvents = listener;
    listener.on<ParticipantConnectionQualityUpdatedEvent>((event) {
      if (!identical(_room, room) && voicePhase != VoicePhase.joining) return;
      if (!identical(event.participant, room.localParticipant)) return;
      notifyListeners();
    });
    listener.on<AudioSenderStatsEvent>((event) {
      if (!identical(_room, room) && voicePhase != VoicePhase.joining) return;
      final ping = voiceRttMilliseconds(event.stats.roundTripTime);
      if (ping == null) return;
      if (_voicePingMs == ping) return;
      _voicePingMs = ping;
      notifyListeners();
    });
    listener.on<RoomAttemptReconnectEvent>((event) {
      if (!identical(_room, room) ||
          voicePhase != VoicePhase.reconnecting ||
          shouldAllowVoiceReconnectAttempt(event.attempt)) {
        return;
      }
      error =
          'Не удалось восстановить голосовое соединение после $voiceReconnectAttemptLimit попыток. Подключитесь ещё раз.';
      unawaited(leaveVoice());
    });
    listener.on<RoomReconnectingEvent>((_) {
      if (!identical(_room, room) && voicePhase != VoicePhase.joining) return;
      voicePhase = VoicePhase.reconnecting;
      _voicePingMs = null;
      _observeVoiceStreamStarts(room);
      notifyListeners();
    });
    listener.on<RoomResumingEvent>((_) {
      if (!identical(_room, room) && voicePhase != VoicePhase.joining) return;
      voicePhase = VoicePhase.reconnecting;
      _voicePingMs = null;
      _observeVoiceStreamStarts(room);
      notifyListeners();
    });
    listener.on<RoomReconnectedEvent>((_) {
      if (!identical(_room, room)) return;
      voicePhase = _listenerOnly ? VoicePhase.listener : VoicePhase.connected;
      _observeVoiceStreamStarts(room);
      _subscribeCurrentRemoteVoiceTracks(room);
      final selectedIdentity = _selectedRemoteScreenViewerIdentity;
      if (selectedIdentity != null) {
        _subscribeRemoteScreenForViewing(room, selectedIdentity);
      }
      unawaited(_applySavedVoiceVolumes(room));
      if (deafened) unawaited(_deafenRemoteAudio(room));
      if (audioActivationMode == AudioActivationMode.ptt) {
        if (pushToTalkPressed && !deafened) {
          _listenerOnly = false;
          voicePhase = VoicePhase.connected;
        }
        unawaited(_applyMicrophoneMuted(!pushToTalkPressed || deafened));
      }
      notifyListeners();
    });
    listener.on<TrackSubscribedEvent>((event) {
      if (!identical(_room, room)) return;
      if (event.publication.source == TrackSource.screenShareVideo &&
          event.track is RemoteVideoTrack) {
        final waiter = _screenPreviewTrackWaiters[event.publication.sid];
        if (waiter != null && !waiter.isCompleted) {
          waiter.complete(event.track as RemoteVideoTrack);
        }
      }
      if (event.track is RemoteAudioTrack) {
        if (deafened) unawaited(event.publication.disable());
        unawaited(
          _applySavedAudioVolume(event.participant, event.publication.source),
        );
      }
    });
    void refreshVoiceNavigation() {
      if (!identical(_room, room)) return;
      _observeVoiceStreamStarts(room);
      notifyListeners();
    }

    listener.on<ParticipantConnectedEvent>((_) => refreshVoiceNavigation());
    listener.on<ParticipantDisconnectedEvent>((event) {
      screenThumbnails.remove(event.participant.identity);
      final endedTrackIds = _screenThumbnailRemoteTrackIds.entries
          .where((entry) => entry.value == event.participant.identity)
          .map((entry) => entry.key)
          .toList(growable: false);
      for (final trackId in endedTrackIds) {
        final waiter = _screenPreviewTrackWaiters[trackId];
        if (waiter != null && !waiter.isCompleted) waiter.complete(null);
        _screenThumbnailRemoteTrackIds.remove(trackId);
      }
      if (_selectedRemoteScreenViewerIdentity == event.participant.identity) {
        _selectedRemoteScreenViewerIdentity = null;
      }
      refreshVoiceNavigation();
    });
    listener.on<ActiveSpeakersChangedEvent>((_) => refreshVoiceNavigation());
    listener.on<TrackPublishedEvent>((event) {
      if (identical(_room, room)) {
        if (event.publication.source == TrackSource.microphone) {
          unawaited(_setRemoteTrackSubscription(event.publication, true));
        } else if (event.publication.source == TrackSource.screenShareVideo) {
          _queueRemoteScreenThumbnail(
            room,
            event.participant,
            event.publication,
          );
        }
      }
      refreshVoiceNavigation();
    });
    listener.on<TrackUnpublishedEvent>((event) {
      if (event.publication.source == TrackSource.screenShareVideo) {
        screenThumbnails.remove(event.participant.identity);
        _screenThumbnailRemoteTrackIds.remove(event.publication.sid);
        final waiter = _screenPreviewTrackWaiters[event.publication.sid];
        if (waiter != null && !waiter.isCompleted) waiter.complete(null);
        if (_selectedRemoteScreenViewerIdentity == event.participant.identity) {
          unawaited(selectRemoteScreenForViewing(null));
        }
      }
      refreshVoiceNavigation();
    });
    listener.on<TrackMutedEvent>((_) => refreshVoiceNavigation());
    listener.on<TrackUnmutedEvent>((_) => refreshVoiceNavigation());
    listener.on<TrackSubscribedEvent>((_) => refreshVoiceNavigation());
    listener.on<TrackUnsubscribedEvent>((event) {
      if (event.publication.source == TrackSource.screenShareVideo) {
        _screenThumbnailRemoteTrackIds.remove(event.publication.sid);
        final waiter = _screenPreviewTrackWaiters[event.publication.sid];
        if (waiter != null && !waiter.isCompleted) waiter.complete(null);
      }
      refreshVoiceNavigation();
    });
    listener.on<LocalTrackPublishedEvent>((event) {
      if (!identical(_room, room) ||
          event.publication.source != TrackSource.screenShareVideo) {
        return;
      }
      screenSharePhase = ScreenSharePhase.sharing;
      screenShareError = null;
      final track = event.publication.track;
      if (track is LocalVideoTrack &&
          nativeScreenMetricsPlatform(defaultTargetPlatform) != null) {
        _startScreenShareMetrics(track);
      }
      if (track is LocalVideoTrack) {
        _startScreenThumbnailCapture(room, track);
      }
      notifyListeners();
    });
    listener.on<LocalTrackUnpublishedEvent>((event) {
      if (!identical(_room, room) ||
          event.publication.source != TrackSource.screenShareVideo) {
        return;
      }
      screenSharePhase = ScreenSharePhase.idle;
      _stopScreenShareMetrics();
      _stopScreenThumbnailCapture();
      final localIdentity = room.localParticipant?.identity;
      if (localIdentity != null) screenThumbnails.remove(localIdentity);
      unawaited(_disableAndroidScreenShareBackground());
      notifyListeners();
    });
    listener.on<RoomDisconnectedEvent>((event) {
      if (!identical(_room, room) || voicePhase == VoicePhase.leaving) return;
      unawaited(_handleUnexpectedVoiceDisconnect(room, event));
    });
  }

  void _subscribeCurrentRemoteVoiceTracks(Room room) {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications.where(
        (item) => item.source == TrackSource.microphone,
      )) {
        unawaited(_setRemoteTrackSubscription(publication, true));
      }
      for (final publication in participant.videoTrackPublications.where(
        (item) => item.source == TrackSource.screenShareVideo,
      )) {
        _queueRemoteScreenThumbnail(room, participant, publication);
      }
    }
  }

  void _queueRemoteScreenThumbnail(
    Room room,
    RemoteParticipant participant,
    RemoteTrackPublication publication,
  ) {
    final queue = _screenPreviewSubscriptionQueue;
    if (queue == null ||
        queue.isClosed ||
        publication.source != TrackSource.screenShareVideo ||
        publication.muted ||
        _selectedRemoteScreenViewerIdentity == participant.identity) {
      return;
    }
    unawaited(
      queue.enqueue(publication.sid, () async {
        if (!_isRemoteScreenPublicationActive(room, participant, publication) ||
            _selectedRemoteScreenViewerIdentity == participant.identity) {
          return;
        }
        final trackId = publication.sid;
        final waiter = Completer<RemoteVideoTrack?>();
        _screenPreviewTrackWaiters[trackId] = waiter;
        _screenThumbnailRemoteTrackIds[trackId] = participant.identity;
        try {
          final existingTrack = publication.track;
          if (existingTrack is RemoteVideoTrack) {
            waiter.complete(existingTrack);
          }
          final track =
              await withTemporaryScreenPreviewSubscription<RemoteVideoTrack>(
                subscribe: publication.subscribe,
                action: () => waiter.future.timeout(
                  const Duration(seconds: 4),
                  onTimeout: () => null,
                ),
                unsubscribe: publication.unsubscribe,
                keepSubscribed: () =>
                    _selectedRemoteScreenViewerIdentity == participant.identity,
              );
          if (track == null ||
              _selectedRemoteScreenViewerIdentity == participant.identity ||
              !_isRemoteScreenPublicationActive(
                room,
                participant,
                publication,
              )) {
            return;
          }
          await _captureRemoteScreenThumbnail(
            room,
            participant,
            publication,
            track,
          );
        } catch (_) {
          // A failed thumbnail subscription must not affect voice playback.
        } finally {
          if (identical(_screenPreviewTrackWaiters[trackId], waiter)) {
            _screenPreviewTrackWaiters.remove(trackId);
          }
          _screenThumbnailRemoteTrackIds.remove(trackId);
          if (_isRemoteScreenPublicationActive(
                room,
                participant,
                publication,
              ) &&
              _selectedRemoteScreenViewerIdentity == participant.identity) {
            // A selection can race the temporary unsubscribe's completion.
            // Restore persistent playback after the preview has left the queue.
            await _setRemoteTrackSubscription(publication, true);
          }
        }
      }),
    );
  }

  bool _isRemoteScreenPublicationActive(
    Room room,
    RemoteParticipant participant,
    RemoteTrackPublication publication,
  ) =>
      identical(_room, room) &&
      _screenPreviewSubscriptionQueue?.isClosed == false &&
      identical(room.remoteParticipants[participant.identity], participant) &&
      participant.videoTrackPublications.any(
        (item) => identical(item, publication),
      );

  Future<void> _captureRemoteScreenThumbnail(
    Room room,
    RemoteParticipant participant,
    RemoteTrackPublication publication,
    RemoteVideoTrack track,
  ) async {
    bool isActive() =>
        _isRemoteScreenPublicationActive(room, participant, publication) &&
        identical(publication.track, track);

    final thumbnail = await captureRemoteScreenThumbnail(
      hasDecodedFrames: () async {
        final decoded = (await track.getReceiverStats())?.framesDecoded;
        return decoded != null && decoded > 0;
      },
      capture: () => _screenThumbnailCaptureQueue.run(
        () async => (await track.mediaStreamTrack.captureFrame()).asUint8List(),
      ),
      encode: (frame) => compute(encodeScreenThumbnail, frame),
      isActive: isActive,
    );
    if (thumbnail == null || !isActive()) return;
    screenThumbnails[participant.identity] = thumbnail;
    notifyListeners();
  }

  void _closeScreenPreviewSubscriptions() {
    _screenPreviewSubscriptionQueue?.close();
    _screenPreviewSubscriptionQueue = null;
    for (final waiter in _screenPreviewTrackWaiters.values) {
      if (!waiter.isCompleted) waiter.complete(null);
    }
    _screenPreviewTrackWaiters.clear();
    _screenThumbnailRemoteTrackIds.clear();
  }

  void _startVoiceConnectionStatsPolling(Room room) {
    _stopVoiceConnectionStatsPolling();
    final revision = _voiceConnectionStatsRevision;
    final platform = nativeScreenMetricsPlatform(defaultTargetPlatform);
    final reporter = platform == null
        ? null
        : ConnectionMediaReporter(api.reportScreenShareMetrics, platform);

    Future<void> sample() async {
      if (_voiceConnectionStatsBusy ||
          revision != _voiceConnectionStatsRevision ||
          !identical(_room, room) ||
          (voicePhase != VoicePhase.connected &&
              voicePhase != VoicePhase.listener)) {
        return;
      }
      _voiceConnectionStatsBusy = true;
      try {
        final reports = await room.getPeerConnectionStats();
        if (revision != _voiceConnectionStatsRevision ||
            !identical(_room, room) ||
            (voicePhase != VoicePhase.connected &&
                voicePhase != VoicePhase.listener)) {
          return;
        }
        final measuredPing = voiceRttMillisecondsFromPeerConnections(reports);
        if (reporter != null) {
          unawaited(
            reporter.submit(
              measuredPing,
              room.localParticipant?.connectionQuality ??
                  ConnectionQuality.unknown,
            ),
          );
        }
        final ping = voicePingAfterMeasurement(
          previousPingMilliseconds: _voicePingMs,
          measuredPingMilliseconds: measuredPing,
        );
        if (_voicePingMs != ping) {
          _voicePingMs = ping;
          notifyListeners();
        }
      } catch (_) {
        // Keep voice controls working if this platform can't read connection
        // stats; track-scoped LiveKit stats can still provide audio RTT.
      } finally {
        if (revision == _voiceConnectionStatsRevision) {
          _voiceConnectionStatsBusy = false;
        }
      }
    }

    _voiceConnectionStatsTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(sample()),
    );
    unawaited(sample());
  }

  void _stopVoiceConnectionStatsPolling() {
    _voiceConnectionStatsRevision++;
    _voiceConnectionStatsTimer?.cancel();
    _voiceConnectionStatsTimer = null;
    _voiceConnectionStatsBusy = false;
  }

  Future<void> startScreenShare({
    String? sourceId,
    ScreenShareQuality? quality,
    VideoDimensions? sourceDimensions,
  }) async {
    final room = _room;
    final participant = room?.localParticipant;
    if (room == null ||
        participant == null ||
        voicePhase != VoicePhase.connected &&
            voicePhase != VoicePhase.listener) {
      screenShareError =
          'Подключитесь к голосовому каналу перед демонстрацией.';
      screenSharePhase = ScreenSharePhase.error;
      notifyListeners();
      return;
    }
    if (screenSharePhase == ScreenSharePhase.starting ||
        screenSharePhase == ScreenSharePhase.sharing) {
      return;
    }
    screenSharePhase = ScreenSharePhase.starting;
    screenShareError = null;
    screenShareQuality = quality ?? screenShareQuality;
    notifyListeners();
    var androidBackgroundEnabled = false;
    LocalVideoTrack? pendingScreenShareTrack;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final permitted = await rtc.Helper.requestCapturePermission();
        if (!permitted) throw StateError('Захват экрана не разрешён.');
        final initialized = await FlutterBackground.initialize(
          androidConfig: const FlutterBackgroundAndroidConfig(
            notificationTitle: 'Демонстрация экрана',
            notificationText: 'Экран передаётся участникам голосового канала',
            shouldRequestBatteryOptimizationsOff: false,
          ),
        );
        if (!initialized ||
            !await FlutterBackground.enableBackgroundExecution()) {
          throw StateError('Не удалось включить фоновую передачу экрана.');
        }
        androidBackgroundEnabled = true;
        final foregroundStarted = await const MethodChannel(
          'boohtacord/screen_share',
        ).invokeMethod<bool>('awaitForegroundService', {'timeoutMs': 3000});
        if (foregroundStarted != true) {
          throw StateError(
            'Android не успел запустить foreground service для захвата экрана.',
          );
        }
      }
      final captureOptions = ScreenShareCaptureOptions(
        sourceId: sourceId,
        maxFrameRate: screenShareQuality.captureFrameRate.toDouble(),
        params: screenShareQuality.captureParameters,
      );
      pendingScreenShareTrack = await LocalVideoTrack.createScreenShareTrack(
        captureOptions,
      );
      final captureDimensions = _screenShareCaptureDimensions(
        pendingScreenShareTrack,
      );
      await participant.publishVideoTrack(
        pendingScreenShareTrack,
        publishOptions: screenShareQuality.publishOptions(
          // Use a single layer on Android while investigating receiver-side
          // clipping reported across Flutter and web viewers. Verify on-device
          // before deciding whether the bandwidth trade-off is acceptable.
          simulcast: defaultTargetPlatform != TargetPlatform.android,
          sourceDimensions:
              captureDimensions ??
              (defaultTargetPlatform == TargetPlatform.windows
                  ? sourceDimensions
                  : null),
        ),
      );
      // Ownership transfers to the participant after a successful publish.
      pendingScreenShareTrack = null;
      screenSharePhase = ScreenSharePhase.sharing;
      notifyListeners();
    } catch (cause) {
      _stopScreenShareMetrics();
      try {
        await pendingScreenShareTrack?.stop();
      } catch (_) {}
      if (androidBackgroundEnabled) {
        await _disableAndroidScreenShareBackground();
      }
      screenSharePhase = ScreenSharePhase.error;
      screenShareError =
          'Не удалось начать демонстрацию экрана: ${screenShareFailureDetail(cause)}';
      notifyListeners();
    }
  }

  Future<void> stopScreenShare() async {
    final participant = _room?.localParticipant;
    if (participant == null || screenSharePhase == ScreenSharePhase.idle) {
      return;
    }
    screenSharePhase = ScreenSharePhase.stopping;
    _stopScreenShareMetrics();
    _stopScreenThumbnailCapture();
    notifyListeners();
    try {
      await participant.setScreenShareEnabled(false);
      screenSharePhase = ScreenSharePhase.idle;
      await _disableAndroidScreenShareBackground();
    } catch (cause) {
      screenSharePhase = ScreenSharePhase.error;
      screenShareError =
          'Не удалось остановить демонстрацию: ${screenShareFailureDetail(cause)}';
    }
    notifyListeners();
  }

  void _startScreenThumbnailCapture(Room room, LocalVideoTrack track) {
    _stopScreenThumbnailCapture();
    _screenThumbnailLastLoggedResult = null;
    _screenThumbnailTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_captureLocalScreenThumbnail(room, track));
    });
    unawaited(_captureLocalScreenThumbnail(room, track));
  }

  Future<void> _captureLocalScreenThumbnail(
    Room room,
    LocalVideoTrack track,
  ) async {
    if (_screenThumbnailBusy ||
        !identical(_room, room) ||
        screenSharePhase != ScreenSharePhase.sharing) {
      return;
    }
    _screenThumbnailBusy = true;
    try {
      final result = await captureScreenThumbnailFrame(
        capture: () => _screenThumbnailCaptureQueue.run(
          () async =>
              (await track.mediaStreamTrack.captureFrame()).asUint8List(),
        ),
        encode: (frame) => compute(encodeScreenThumbnail, frame),
        storeLocally: (thumbnail) {
          final localIdentity = room.localParticipant?.identity;
          if (localIdentity == null) return;
          screenThumbnails[localIdentity] = thumbnail;
          notifyListeners();
        },
        isActive: () =>
            identical(_room, room) &&
            screenSharePhase == ScreenSharePhase.sharing,
      );
      if (_screenThumbnailLastLoggedResult != result) {
        debugPrint('[screen-thumbnail] local=${result.name}');
        _screenThumbnailLastLoggedResult = result;
      }
    } catch (_) {
      // Thumbnail diagnostics must never interrupt the media publication.
    } finally {
      _screenThumbnailBusy = false;
    }
  }

  void _stopScreenThumbnailCapture() {
    _screenThumbnailTimer?.cancel();
    _screenThumbnailTimer = null;
    _screenThumbnailLastLoggedResult = null;
  }

  Future<void> updateScreenShareQuality(ScreenShareQuality quality) async {
    if (screenSharePhase != ScreenSharePhase.sharing) return;
    final track = _room?.localParticipant
        ?.getTrackPublicationBySource(TrackSource.screenShareVideo)
        ?.track;
    if (track is! LocalVideoTrack || track.sender == null) {
      screenShareError = 'Активная видеодорожка демонстрации недоступна.';
      notifyListeners();
      return;
    }
    try {
      final sender = track.sender!;
      final parameters = sender.parameters;
      final encodings = parameters.encodings;
      if (encodings == null || encodings.isEmpty) {
        throw StateError('Видеоэнкодер не предоставил параметры качества.');
      }
      final source = _screenShareCaptureDimensions(track);
      final baseScale = encodings
          .map((encoding) => encoding.scaleResolutionDownBy ?? 1.0)
          .reduce((left, right) => left < right ? left : right);
      for (final encoding in encodings) {
        final relativeScale =
            (encoding.scaleResolutionDownBy ?? 1.0) / baseScale;
        encoding.maxBitrate =
            (quality.maxBitrate * 1000 / (relativeScale * relativeScale))
                .round()
                .clamp(200000, quality.maxBitrate * 1000);
        encoding.maxFramerate = quality.frameRate;
        encoding.scaleResolutionDownBy = source == null
            ? relativeScale
            : quality.scaleResolutionDownBy(source) * relativeScale;
      }
      final applied = await sender.setParameters(parameters);
      if (applied == false) {
        throw StateError('Энкодер отклонил новые параметры.');
      }
      screenShareQuality = quality;
      screenShareError = null;
    } catch (cause) {
      screenShareError =
          'Не удалось изменить качество: ${screenShareFailureDetail(cause)}';
    }
    notifyListeners();
  }

  void _startScreenShareMetrics(LocalVideoTrack track) {
    _stopScreenShareMetrics();
    final revision = _screenShareMetricsGate.generation;
    _screenShareMetricsTrack = track;
    _screenShareMetricsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_sampleScreenShareMetrics(track, revision));
    });
    unawaited(_sampleScreenShareMetrics(track, revision));
  }

  void _stopScreenShareMetrics() {
    _stopScreenThumbnailCapture();
    _screenShareMetricsGate.nextGeneration();
    _screenShareMetricsTimer?.cancel();
    _screenShareMetricsTimer = null;
    _screenShareMetricsTrack = null;
    _previousScreenShareMetrics = null;
    _senderMediaTelemetry.clear();
  }

  Future<void> _sampleScreenShareMetrics(
    LocalVideoTrack track,
    int revision,
  ) async {
    if (revision != _screenShareMetricsGate.generation ||
        !identical(track, _screenShareMetricsTrack) ||
        screenSharePhase != ScreenSharePhase.sharing ||
        voicePhase == VoicePhase.leaving ||
        !_screenShareMetricsGate.tryEnter(revision)) {
      return;
    }
    try {
      final stats = await track.getSenderStats();
      final current = screenShareSenderSnapshotFromStats(
        stats
            .map(
              (item) => ScreenShareSenderStats(
                timestampMs: webRtcStatsTimestampMs(item.timestamp),
                frameWidth: item.frameWidth,
                frameHeight: item.frameHeight,
                bytesSent: item.bytesSent,
                framesSent: item.framesSent,
                framesPerSecond: item.framesPerSecond,
                roundTripTimeSeconds: item.roundTripTime,
              ),
            )
            .toList(growable: false),
      );
      if (revision != _screenShareMetricsGate.generation ||
          !identical(track, _screenShareMetricsTrack) ||
          screenSharePhase != ScreenSharePhase.sharing) {
        return;
      }
      final report = buildScreenShareSenderReport(
        previous: _previousScreenShareMetrics,
        current: current,
        platform: nativeScreenMetricsPlatform(defaultTargetPlatform)!,
      );
      _previousScreenShareMetrics = current;
      try {
        final samples = stats
            .map(
              (item) => SenderMediaSample(
                streamId: item.streamId,
                timestamp: webRtcStatsTimestampMs(item.timestamp),
                frameWidth: item.frameWidth,
                frameHeight: item.frameHeight,
                packetsSent: item.packetsSent,
                packetsLost: item.packetsLost,
                qualityLimitationReason: item.qualityLimitationReason,
              ),
            )
            .toList();
        await api.reportScreenShareMetrics({
          ...report.toJson(),
          ..._senderMediaTelemetry.fields(
            samples,
            screenShareQuality,
            _room?.localParticipant?.connectionQuality ??
                ConnectionQuality.unknown,
          ),
        });
      } catch (_) {
        // Diagnostic telemetry is best-effort and must not interrupt sharing.
      }
    } catch (_) {
      // Some platform WebRTC implementations do not expose sender stats.
    } finally {
      _screenShareMetricsGate.leave(revision);
    }
  }

  Future<void> _disableAndroidScreenShareBackground() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        !FlutterBackground.isBackgroundExecutionEnabled) {
      return;
    }
    try {
      await FlutterBackground.disableBackgroundExecution();
    } catch (_) {}
  }

  Future<void> _disposeVoiceEvents() async {
    _closeScreenPreviewSubscriptions();
    final listener = _voiceEvents;
    _voiceEvents = null;
    await listener?.dispose();
  }

  String? _voiceAccountId(RemoteParticipant participant) {
    final metadata = participant.metadata;
    if (metadata == null || !metadata.startsWith('account:')) return null;
    final accountId = metadata.substring('account:'.length);
    return accountId.isEmpty ? null : accountId;
  }

  RemoteParticipant? voiceParticipantForAccount(String accountId) => _room
      ?.remoteParticipants
      .values
      .where((participant) => _voiceAccountId(participant) == accountId)
      .firstOrNull;

  int? participantVolume(RemoteParticipant participant) {
    final accountId = _voiceAccountId(participant);
    return accountId == null
        ? null
        : _voiceVolumePreferences?.participant(accountId) ?? 100;
  }

  int? screenShareVolume(RemoteParticipant participant) {
    final accountId = _voiceAccountId(participant);
    return accountId == null
        ? null
        : _voiceVolumePreferences?.screen(accountId) ?? 100;
  }

  bool screenShareAudioMuted(RemoteParticipant participant) =>
      _mutedScreenShareAudioIdentities.contains(participant.identity);

  Future<void> setScreenShareAudioMuted(
    RemoteParticipant participant,
    bool muted,
  ) async {
    final room = _room;
    if (room == null || !room.remoteParticipants.values.contains(participant)) {
      return;
    }
    final identity = participant.identity;
    if (muted) {
      _mutedScreenShareAudioIdentities.add(identity);
    } else {
      _mutedScreenShareAudioIdentities.remove(identity);
    }
    final accountId = _voiceAccountId(participant);
    final savedVolume = accountId == null
        ? 100
        : _voiceVolumePreferences?.screen(accountId) ?? 100;
    try {
      await _applyParticipantVolume(
        participant,
        muted ? 0 : savedVolume,
        TrackSource.screenShareAudio,
      );
    } catch (_) {
      if (muted) {
        _mutedScreenShareAudioIdentities.remove(identity);
      } else {
        _mutedScreenShareAudioIdentities.add(identity);
      }
      error = 'Не удалось изменить звук демонстрации.';
    }
    notifyListeners();
  }

  Future<void> setParticipantVolume(
    RemoteParticipant participant,
    num percent,
  ) async {
    final room = _room;
    final preferences = _voiceVolumePreferences;
    final accountId = _voiceAccountId(participant);
    if (room == null ||
        preferences == null ||
        accountId == null ||
        !room.remoteParticipants.values.contains(participant)) {
      return;
    }
    final level = VoiceVolumePreferences.normalize(percent);
    try {
      await Future.wait([
        preferences.setParticipant(accountId, level),
        _applyParticipantVolume(participant, level),
      ]);
      notifyListeners();
    } catch (_) {
      error = 'Не удалось изменить или сохранить громкость участника.';
      notifyListeners();
    }
  }

  Future<void> setScreenShareVolume(
    RemoteParticipant participant,
    num percent,
  ) async {
    final room = _room;
    final preferences = _voiceVolumePreferences;
    final accountId = _voiceAccountId(participant);
    if (room == null ||
        preferences == null ||
        accountId == null ||
        !room.remoteParticipants.values.contains(participant)) {
      return;
    }
    final level = VoiceVolumePreferences.normalize(percent);
    try {
      await Future.wait([
        preferences.setScreen(accountId, level),
        _applyParticipantVolume(
          participant,
          screenShareAudioMuted(participant) ? 0 : level,
          TrackSource.screenShareAudio,
        ),
      ]);
      notifyListeners();
    } catch (_) {
      error = 'Не удалось изменить или сохранить громкость демонстрации.';
      notifyListeners();
    }
  }

  Future<void> _applySavedVoiceVolumes(Room room) async {
    for (final participant in room.remoteParticipants.values) {
      await _applySavedParticipantVolume(participant);
      await _applySavedAudioVolume(participant, TrackSource.screenShareAudio);
    }
  }

  Future<void> _applySavedParticipantVolume(RemoteParticipant participant) =>
      _applySavedAudioVolume(participant, TrackSource.microphone);

  Future<void> _applySavedAudioVolume(
    RemoteParticipant participant,
    TrackSource source,
  ) async {
    try {
      if (source == TrackSource.screenShareAudio &&
          screenShareAudioMuted(participant)) {
        await _applyParticipantVolume(participant, 0, source);
        return;
      }
      final accountId = _voiceAccountId(participant);
      final preferences = _voiceVolumePreferences;
      if (accountId == null || preferences == null) return;
      await _applyParticipantVolume(
        participant,
        source == TrackSource.screenShareAudio
            ? preferences.screen(accountId)
            : preferences.participant(accountId),
        source,
      );
    } catch (_) {
      error = 'Не удалось применить сохранённую громкость участника.';
      notifyListeners();
    }
  }

  Future<void> _applyParticipantVolume(
    RemoteParticipant participant,
    int level, [
    TrackSource source = TrackSource.microphone,
  ]) async {
    for (final publication in participant.audioTrackPublications) {
      if (publication.source != source || publication.track == null) {
        continue;
      }
      await rtc.Helper.setVolume(
        level / 100,
        publication.track!.mediaStreamTrack,
      );
    }
  }

  Future<void> _deafenRemoteAudio(Room room) async {
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        await publication.disable();
      }
    }
  }

  Future<void> _handleUnexpectedVoiceDisconnect(
    Room room,
    RoomDisconnectedEvent event,
  ) async {
    if (!identical(_room, room) || voicePhase == VoicePhase.leaving) return;
    _clearVoiceStreamNotice(resetTracker: true, notify: false);
    _stopVoiceConnectionStatsPolling();
    _stopScreenShareMetrics();
    final leaseId = _leaseId;
    _room = null;
    _voicePingMs = null;
    _leaseId = null;
    voiceChannel = null;
    screenThumbnails.clear();
    _screenThumbnailRemoteTrackIds.clear();
    _mutedScreenShareAudioIdentities.clear();
    screenSharePhase = ScreenSharePhase.idle;
    screenShareError = null;
    await _disableAndroidScreenShareBackground();
    microphoneMuted = false;
    microphoneUnavailable = false;
    deafened = false;
    pushToTalkPressed = false;
    _mutedBeforeDeafen = false;
    _listenerOnly = false;
    voicePhase = VoicePhase.error;
    error = switch (event.reason) {
      DisconnectReason.duplicateIdentity =>
        'Голосовое подключение открыто в другом окне. Перенесите его оттуда.',
      DisconnectReason.participantRemoved =>
        'Администратор отключил вас от голосового канала.',
      DisconnectReason.roomDeleted => 'Голосовая комната была закрыта.',
      DisconnectReason.reconnectAttemptsExceeded =>
        'Не удалось восстановить голосовое соединение после $voiceReconnectAttemptLimit попыток. Подключитесь ещё раз.',
      _ => 'Связь с голосовым каналом потеряна. Подключитесь ещё раз.',
    };
    await _disposeVoiceEvents();
    try {
      await AndroidAudioDevices.clearNativeOutput();
    } catch (_) {}
    if (leaseId != null) {
      try {
        await api.releaseVoice(leaseId);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> toggleMicrophone() async {
    if (_room == null ||
        deafened ||
        audioActivationMode == AudioActivationMode.ptt) {
      return;
    }
    microphoneMuted = !microphoneMuted;
    try {
      await _room!.localParticipant?.setMicrophoneEnabled(
        !microphoneMuted,
        audioCaptureOptions: _audioCaptureOptions,
      );
      if (!microphoneMuted) {
        _refreshAudioDevicesAfterMicrophoneCapture();
        error = null;
        microphoneUnavailable = false;
        _listenerOnly = false;
        if (voicePhase == VoicePhase.listener) {
          voicePhase = VoicePhase.connected;
        }
      }
    } catch (cause) {
      microphoneMuted = true;
      microphoneUnavailable = true;
      error = _message(cause);
    }
    notifyListeners();
  }

  Future<void> toggleDeafen() async {
    final room = _room;
    if (room == null || deafenChanging || voicePhase == VoicePhase.leaving) {
      return;
    }
    final wasDeafened = deafened;
    final wasMicrophoneMuted = microphoneMuted;
    final nextDeafened = !wasDeafened;
    deafenChanging = true;
    error = null;
    notifyListeners();
    try {
      if (nextDeafened) {
        _mutedBeforeDeafen = wasMicrophoneMuted;
        if (audioActivationMode == AudioActivationMode.ptt ||
            !microphoneMuted) {
          if (!await _applyMicrophoneMuted(true)) {
            throw StateError(
              audioActivationError ?? 'Не удалось выключить микрофон.',
            );
          }
        }
        for (final participant in room.remoteParticipants.values) {
          for (final publication in participant.audioTrackPublications) {
            await publication.disable();
          }
        }
        deafened = true;
      } else {
        for (final participant in room.remoteParticipants.values) {
          for (final publication in participant.audioTrackPublications) {
            await publication.enable();
          }
        }
        final shouldUnmute = audioActivationMode == AudioActivationMode.ptt
            ? pushToTalkPressed
            : !_mutedBeforeDeafen;
        if (shouldUnmute && !await _applyMicrophoneMuted(false)) {
          throw StateError(
            audioActivationError ?? 'Не удалось включить микрофон.',
          );
        }
        deafened = false;
        _mutedBeforeDeafen = false;
      }
    } catch (cause) {
      if (identical(_room, room) && voicePhase != VoicePhase.leaving) {
        for (final participant in room.remoteParticipants.values) {
          for (final publication in participant.audioTrackPublications) {
            try {
              if (wasDeafened) {
                await publication.disable();
              } else {
                await publication.enable();
              }
            } catch (_) {}
          }
        }
        if (microphoneMuted != wasMicrophoneMuted) {
          await _applyMicrophoneMuted(wasMicrophoneMuted);
        }
      }
      deafened = wasDeafened;
      error = _message(cause);
    } finally {
      deafenChanging = false;
      notifyListeners();
    }
  }

  Future<void> leaveVoice() async {
    if (_room == null && _leaseId == null) return;
    _stopVoiceConnectionStatsPolling();
    voicePhase = VoicePhase.leaving;
    _clearVoiceStreamNotice(resetTracker: true, notify: false);
    pushToTalkPressed = false;
    notifyListeners();
    if (screenSharePhase == ScreenSharePhase.sharing ||
        screenSharePhase == ScreenSharePhase.starting) {
      await stopScreenShare();
    }
    final leaseId = _leaseId;
    try {
      await _room?.disconnect();
    } catch (_) {}
    try {
      await AndroidAudioDevices.clearNativeOutput();
    } catch (_) {}
    await _disposeVoiceEvents();
    if (leaseId != null) {
      try {
        await api.releaseVoice(leaseId);
      } catch (cause) {
        error = _message(cause);
      }
    }
    _room = null;
    _voicePingMs = null;
    _leaseId = null;
    voiceChannel = null;
    _mutedScreenShareAudioIdentities.clear();
    microphoneMuted = false;
    microphoneUnavailable = false;
    deafened = false;
    _listenerOnly = false;
    _mutedBeforeDeafen = false;
    _microphoneMutedBeforePtt = false;
    voicePhase = VoicePhase.idle;
    screenSharePhase = ScreenSharePhase.idle;
    screenShareError = null;
    notifyListeners();
  }

  String _message(Object cause) {
    if (cause is ApiFailure) return cause.message;
    if (cause is PlatformException) {
      final code = String.fromCharCodes(
        cause.code.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '').runes.take(80),
      );
      var detail = (cause.message ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceAllMapped(
            RegExp(
              r'(password|token|cookie|authorization)\s*[:=]\s*\S+',
              caseSensitive: false,
            ),
            (match) => '${match[1]}=[скрыто]',
          );
      final detailRunes = detail.runes.toList(growable: false);
      if (detailRunes.length > 240) {
        detail = '${String.fromCharCodes(detailRunes.take(240))}…';
      }
      final context = [
        if (code.isNotEmpty) code,
        if (detail.isNotEmpty) detail,
      ].join(' — ');
      return context.isEmpty
          ? 'Ошибка системного API.'
          : 'Ошибка системного API: $context';
    }
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
