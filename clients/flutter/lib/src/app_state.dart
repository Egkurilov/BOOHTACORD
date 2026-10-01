import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter_background/flutter_background.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;
import 'package:shared_preferences/shared_preferences.dart';

import 'guild_presence_state.dart';
import 'features/audio/devices/controller.dart';
import 'features/session/lifecycle/controller.dart';
import 'features/profile/state/controller.dart';
import 'features/workspace/lifecycle/controller.dart';
import 'features/conversation/lifecycle/controller.dart';
import 'features/realtime/lifecycle/controller.dart';
import 'features/realtime/dispatch/workspace.dart';
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
import 'features/voice/roster_state/controller.dart';
import 'services/screen_thumbnail.dart';
import 'telemetry/report_media/sender.dart';
import 'telemetry/report_media/sender_sample.dart';
import 'telemetry/report_media/connection.dart';

export 'features/session/lifecycle/types.dart';
export 'features/workspace/lifecycle/types.dart';
export 'features/conversation/lifecycle/types.dart';

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
        invalidateOperations: () {
          _profile.cancelOperations();
          _workspace.cancelOperations();
          _conversation.cancelOperations();
          _stopVoiceRosterEvents();
        },
        resume: () async {
          final ticket = _session.scope.capture();
          await _closeRealtime();
          if (!ticket.isActive) return;
          _startVoiceRosterEvents();
          unawaited(_connectRealtime());
        },
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
    _nativeNotifications.sessionScope = _session.scope;
    _nativeNotifications.addListener(notifyListeners);
    _workspace = WorkspaceController(
      api,
      _session.scope,
      effects: WorkspaceEffects(
        audioPanelOpened: () {
          _audioDevices.watch();
          unawaited(refreshAudioDevices());
        },
        selectChannel: _loadChannelHistory,
        openDirect: _loadDirectHistory,
        invalidateText: () => _conversation.invalidateSelection(),
        clearText: () => _conversation.clearText(),
        clearDirect: () => _conversation.clearDirect(),
        error: (value) => error = value,
        message: _message,
      ),
    )..addListener(notifyListeners);
    _conversation = ConversationController(
      api,
      _session.scope,
      _workspace,
      readUser: () => user,
      isReady: () => phase == AppPhase.ready,
      reportError: (value) => error = value,
      formatError: _message,
    )..addListener(notifyListeners);
    _realtime = RealtimeController(
      api,
      _session.scope,
      isReady: () => phase == AppPhase.ready,
      expire: _expireSession,
      invalidatePresence: () => guildPresence.invalidate(),
      dispatch: WorkspaceRealtimeDispatch(
        _workspace,
        _conversation,
        voiceRevoked: _dispatchVoiceRevocation,
        notifyMessage: (event) {
          final unread =
              _addressedUnreadCount(event.kind, event.payload) ??
              (event.kind == 'direct_message.message_created' ? 0 : null);
          unawaited(
            _refreshAndDeliverMessageNotification(
              eventId: event.id,
              kind: event.kind,
              payload: event.payload,
              previousUnread: unread,
            ),
          );
        },
      ).call,
    )..addListener(notifyListeners);
    _voiceRoster = VoiceRosterController(
      api,
      _session.scope,
      isReady: () => phase == AppPhase.ready,
      hasUser: () => user != null,
      message: _message,
      retryDelay: voiceRosterRetryDelay,
      staleTimeout: voiceRosterStaleTimeout,
    )..addListener(notifyListeners);
    _profile = ProfileController(
      api,
      _session.scope,
      error: (value) => error = value,
      formatError: _message,
      refreshMembers: refreshMembers,
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
  late final ProfileController _profile;
  late final WorkspaceController _workspace;
  late final ConversationController _conversation;
  late final RealtimeController _realtime;
  late final VoiceRosterController _voiceRoster;
  @visibleForTesting
  final Duration startupSessionTimeout;
  final NativeNotificationService _nativeNotifications;
  AppPhase get phase => _session.phase;
  set phase(AppPhase value) => _session.phase = value;
  SessionUser? get user => _session.user;
  set user(SessionUser? value) => _session.user = value;
  OwnProfile? get profile => _profile.profile;
  set profile(OwnProfile? value) => _profile.profile = value;
  ChannelTopology? get topology => _workspace.topology;
  set topology(ChannelTopology? value) => _workspace.topology = value;
  List<GuildMember> get members => _workspace.members;
  set members(List<GuildMember> value) => _workspace.members = value;
  GuildPresenceState get guildPresence => _workspace.guildPresence;
  bool get membersLoading => _workspace.membersLoading;
  set membersLoading(bool value) => _workspace.membersLoading = value;
  String? get membersError => _workspace.membersError;
  set membersError(String? value) => _workspace.membersError = value;
  List<VoiceRoomRoster>? get voiceRosters => _voiceRoster.voiceRosters;
  set voiceRosters(List<VoiceRoomRoster>? value) =>
      _voiceRoster.voiceRosters = value;
  String? get voiceRosterError => _voiceRoster.voiceRosterError;
  set voiceRosterError(String? value) => _voiceRoster.voiceRosterError = value;
  List<DirectConversation> get directMessages => _workspace.directMessages;
  set directMessages(List<DirectConversation> value) =>
      _workspace.directMessages = value;
  List<DirectCandidate> get directMessageCandidates =>
      _workspace.directMessageCandidates;
  set directMessageCandidates(List<DirectCandidate> value) =>
      _workspace.directMessageCandidates = value;
  DirectConversation? get selectedDirectMessage =>
      _workspace.selectedDirectMessage;
  set selectedDirectMessage(DirectConversation? value) =>
      _workspace.selectedDirectMessage = value;
  List<DirectChatMessage> get directMessageHistory =>
      _conversation.directMessageHistory;
  set directMessageHistory(List<DirectChatMessage> value) =>
      _conversation.directMessageHistory = value;
  String? get nextDirectMessageCursor => _conversation.nextDirectMessageCursor;
  set nextDirectMessageCursor(String? value) =>
      _conversation.nextDirectMessageCursor = value;
  bool get loadingOlderDirectMessages =>
      _conversation.loadingOlderDirectMessages;
  set loadingOlderDirectMessages(bool value) =>
      _conversation.loadingOlderDirectMessages = value;
  NavigationSection get navigationSection => _workspace.navigationSection;
  set navigationSection(NavigationSection value) =>
      _workspace.navigationSection = value;
  WorkspacePanel get workspacePanel => _workspace.workspacePanel;
  set workspacePanel(WorkspacePanel value) => _workspace.workspacePanel = value;
  SearchMessage? get searchContextMessage => _workspace.searchContextMessage;
  set searchContextMessage(SearchMessage? value) =>
      _workspace.searchContextMessage = value;
  String get searchContextHeading => _workspace.searchContextHeading;
  set searchContextHeading(String value) =>
      _workspace.searchContextHeading = value;
  List<ChatMessage> get searchContextTextMessages =>
      _workspace.searchContextTextMessages;
  set searchContextTextMessages(List<ChatMessage> value) =>
      _workspace.searchContextTextMessages = value;
  List<DirectChatMessage> get searchContextDirectMessages =>
      _workspace.searchContextDirectMessages;
  set searchContextDirectMessages(List<DirectChatMessage> value) =>
      _workspace.searchContextDirectMessages = value;
  bool get loadingSearchContext => _workspace.loadingSearchContext;
  set loadingSearchContext(bool value) =>
      _workspace.loadingSearchContext = value;
  String? get searchContextError => _workspace.searchContextError;
  set searchContextError(String? value) =>
      _workspace.searchContextError = value;
  GuildChannel? get selectedChannel => _workspace.selectedChannel;
  set selectedChannel(GuildChannel? value) =>
      _workspace.selectedChannel = value;
  List<ChatMessage> get messages => _conversation.messages;
  set messages(List<ChatMessage> value) => _conversation.messages = value;
  String? get nextMessageCursor => _conversation.nextMessageCursor;
  set nextMessageCursor(String? value) =>
      _conversation.nextMessageCursor = value;
  bool get loadingOlderMessages => _conversation.loadingOlderMessages;
  set loadingOlderMessages(bool value) =>
      _conversation.loadingOlderMessages = value;
  bool get loadingMessages => _conversation.loadingMessages;
  set loadingMessages(bool value) => _conversation.loadingMessages = value;
  bool get sending => _conversation.sending;
  set sending(bool value) => _conversation.sending = value;
  bool get loadingDirectMessages => _conversation.loadingDirectMessages;
  set loadingDirectMessages(bool value) =>
      _conversation.loadingDirectMessages = value;
  bool get realtimeConnected => _realtime.connected;
  set realtimeConnected(bool value) => _realtime.connected = value;
  bool maintenanceActive = false;
  bool get profileLoading => _profile.profileLoading;
  set profileLoading(bool value) => _profile.profileLoading = value;
  String? get profileLoadError => _profile.profileLoadError;
  set profileLoadError(String? value) => _profile.profileLoadError = value;
  bool get profileSaving => _profile.profileSaving;
  set profileSaving(bool value) => _profile.profileSaving = value;
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
  int get avatarRevision => _profile.avatarRevision;
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
  Timer? _maintenanceTimer;
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
  bool get _notificationAppIsForeground => _nativeNotifications.appIsForeground;

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
  }

  Future<void> disableNotifications() => _nativeNotifications.disable();

  Future<void> refreshNotificationStatus() =>
      _nativeNotifications.refreshStatus();

  void setNotificationAppForeground(bool foreground) {
    _nativeNotifications.appIsForeground = foreground;
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
    _profile.clear();
    _workspace.clear();
    _conversation.clear();
    final ticket = _session.scope.capture();
    _conversation.textHistoryLoadSequence++;
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
    _conversation.sendRetryIds.clear();
    _conversation.pendingTextSends.clear();
    _conversation.pendingDirectSends.clear();
    nextMessageCursor = null;
    _conversation.textHistoryHasLoadedOlderPages = false;
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
    _realtime.eventIds.clear();
    _conversation.lastReadTextAt.clear();
    _conversation.pendingTextReads.clear();
    _conversation.lastReadDirectMessageId = null;
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
    _profile.clear();
    _workspace.clear();
    _conversation.clear();
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
    _profile.clear();
    _workspace.clear();
    _conversation.clear();
    ComposerDraftMemory.clear();
    _conversation.textHistoryLoadSequence++;
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
    _conversation.sendRetryIds.clear();
    _conversation.pendingTextSends.clear();
    _conversation.pendingDirectSends.clear();
    members = const [];
    directMessages = const [];
    directMessageCandidates = const [];
    selectedDirectMessage = null;
    directMessageHistory = const [];
    nextDirectMessageCursor = null;
  }

  Future<void> refreshProfile() => _profile.refreshProfile();

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

  Future<void> refreshVoiceRosters() => _voiceRoster.refreshVoiceRosters();

  void _startVoiceRosterEvents() => _voiceRoster.start();

  void _stopVoiceRosterEvents() => _voiceRoster.stop();

  void toggleWorkspacePanel(WorkspacePanel panel) =>
      _workspace.toggleWorkspacePanel(panel);

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

  Future<bool> saveDisplayName(String value) => _profile.saveDisplayName(value);

  Future<bool> updatePassword(String current, String next) =>
      _profile.updatePassword(current, next);

  Future<bool> uploadAvatar(Uint8List bytes, String contentType) =>
      _profile.uploadAvatar(bytes, contentType);

  Future<bool> deleteAvatar() => _profile.deleteAvatar();

  Future<void> refreshMembers() => _workspace.refreshMembers();
  MemberPresence memberPresence(GuildMember member) =>
      _workspace.memberPresence(member);
  Future<void> refreshDirectMessages() => _workspace.refreshDirectMessages();
  Future<void> showDirectMessages() => _workspace.showDirectMessages();
  void showChannels() => _workspace.showChannels();
  void openSearchPanel() => _workspace.openSearchPanel();
  void closeSearchPanel() => _workspace.closeSearchPanel();
  Future<void> openSearchContext(SearchMessage target, {String? heading}) =>
      _workspace.openSearchContext(target, heading: heading);
  Future<void> returnFromSearchContext() =>
      _workspace.returnFromSearchContext();

  Future<void> openDirectConversation(DirectConversation conversation) =>
      _workspace.openDirectConversation(conversation);

  Future<void> _loadDirectHistory(DirectConversation conversation) =>
      _conversation.loadDirectHistory(conversation);

  Future<bool> loadOlderDirectMessages() =>
      _conversation.loadOlderDirectMessages();

  Future<void> markSelectedDirectMessageRead() =>
      _conversation.markSelectedDirectMessageRead();

  Future<void> createDirectConversation(DirectCandidate candidate) =>
      _workspace.createDirectConversation(candidate);

  Future<bool> sendDirect(
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<MessageAttachment> attachments = const [],
  }) => _conversation.sendDirect(
    body,
    replyToId: replyToId,
    mentionUserIds: mentionUserIds,
    attachments: attachments,
  );

  Future<MessageAttachment> uploadAttachment(
    String fileName,
    Uint8List bytes, {
    String? channelId,
    String? directMessageId,
    void Function(int sent, int total)? onProgress,
  }) => _conversation.uploadAttachment(
    fileName,
    bytes,
    channelId: channelId,
    directMessageId: directMessageId,
    onProgress: onProgress,
  );

  Future<bool> editDirect(DirectChatMessage message, String body) =>
      _conversation.editDirect(message, body);

  Future<MessageEditOutcome> editDirectWithResult(
    DirectChatMessage message,
    String body,
    int expectedRevision, {
    List<String>? mentionUserIds,
  }) => _conversation.editDirectWithResult(
    message,
    body,
    expectedRevision,
    mentionUserIds: mentionUserIds,
  );

  Future<DirectChatMessage?> refreshDirectMessageRevision(
    DirectChatMessage message,
  ) => _conversation.refreshDirectMessageRevision(message);

  Future<void> deleteDirect(DirectChatMessage message) =>
      _conversation.deleteDirect(message);

  Future<void> refreshTopology() => _workspace.refreshTopology();

  Future<void> selectChannel(GuildChannel channel) =>
      _workspace.selectChannel(channel);

  Future<void> _loadChannelHistory(GuildChannel channel) =>
      _conversation.loadChannelHistory(channel);

  Future<void> enterVoiceChannel(GuildChannel channel) async {
    await selectChannel(channel);
    if (channel.kind != ChannelKind.voice || channel.admissionClosed) return;
    if (voiceChannel?.id == channel.id || voicePhase == VoicePhase.joining) {
      return;
    }
    if (voiceChannel != null) await leaveVoice();
    await joinVoice(channel);
  }

  Future<bool> loadOlderMessages() => _conversation.loadOlderMessages();

  /// Refreshes the newest page without discarding history already loaded by
  /// the user. This is used for realtime message events and resynchronization.
  Future<void> refreshSelectedTextHistory() =>
      _conversation.refreshSelectedTextHistory();

  Future<void> markTextChannelRead(String channelId, String messageId) =>
      _conversation.markTextChannelRead(channelId, messageId);

  Future<void> _connectRealtime() => _realtime.connect();

  void _dispatchVoiceRevocation(Map<String, dynamic> payload) {
    final revocation = VoiceLeaseRevocation.parse(
      payload['lease_id'],
      payload['reason'],
      activeLeaseId: _leaseId,
      admissionPending: _voiceAdmissionPending,
    );
    if (revocation != null) {
      if (_voiceAdmissionPending) {
        _revokedVoiceLeasesDuringJoin[revocation.leaseId] = revocation.reason;
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
    final ticket = _session.scope.capture();
    if (!ticket.isActive) return;
    if (eventId == null || kind == null || user == null) return;
    try {
      if (kind == 'message.created') {
        await refreshTopology();
      } else if (kind == 'direct_message.message_created') {
        await refreshDirectMessages();
      }
      if (!ticket.isActive) return;
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

  Future<void> _closeRealtime() => _realtime.close();

  @override
  void dispose() {
    _session.dispose();
    _realtime.dispose();
    _voiceRoster.dispose();
    _profile.dispose();
    _workspace.dispose();
    _conversation.dispose();
    _nativeNotifications.dispose();
    _closeScreenPreviewSubscriptions();
    _maintenanceTimer?.cancel();
    _stopVoiceRosterEvents();
    _voiceStreamNoticeTimer?.cancel();
    _stopVoiceConnectionStatsPolling();
    _stopScreenShareMetrics();
    _audioDevices.dispose();
    api.onUnauthorized = null;
    unawaited(_room?.disconnect());
    super.dispose();
  }

  Future<bool> send(
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<MessageAttachment> attachments = const [],
  }) => _conversation.send(
    body,
    replyToId: replyToId,
    mentionUserIds: mentionUserIds,
    attachments: attachments,
  );

  Future<bool> retryTextSend(String clientMessageId) =>
      _conversation.retryTextSend(clientMessageId);

  Future<bool> retryDirectSend(String clientMessageId) =>
      _conversation.retryDirectSend(clientMessageId);

  Future<bool> editText(ChatMessage message, String body) =>
      _conversation.editText(message, body);

  Future<MessageEditOutcome> editTextWithResult(
    ChatMessage message,
    String body,
    int expectedRevision, {
    List<String>? mentionUserIds,
  }) => _conversation.editTextWithResult(
    message,
    body,
    expectedRevision,
    mentionUserIds: mentionUserIds,
  );

  Future<ChatMessage?> refreshTextMessageRevision(ChatMessage message) =>
      _conversation.refreshTextMessageRevision(message);

  Future<void> deleteText(ChatMessage message) =>
      _conversation.deleteText(message);

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
