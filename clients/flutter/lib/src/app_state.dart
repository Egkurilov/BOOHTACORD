import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

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
import 'services/password_reset_link.dart';
import 'services/screen_share_quality.dart';
import 'services/native_notifications.dart';
import 'services/voice_volume_preferences.dart';
import 'features/voice/roster_state/controller.dart';
import 'features/screen/lifecycle/controller.dart';
import 'features/voice/lifecycle/controller.dart';
export 'features/voice/lifecycle/types.dart';
export 'features/screen/lifecycle/types.dart';

export 'features/session/lifecycle/types.dart';
export 'features/workspace/lifecycle/types.dart';
export 'features/conversation/lifecycle/types.dart';

class AppState extends ChangeNotifier {
  AppState(
    this.api, {
    this.startupSessionTimeout = const Duration(seconds: 20),
    this.voiceRosterRetryDelay = const Duration(seconds: 2),
    this.voiceRosterStaleTimeout = const Duration(seconds: 10),
    Future<List<MediaDevice>> Function()? audioDeviceLoader,
    Stream<List<MediaDevice>>? audioDeviceChanges,
    NativeNotificationService? nativeNotifications,
    Room Function(RoomOptions)? voiceRoomFactory,
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
    _screen = ScreenShareController(
      api,
      _session.scope,
      readRoom: () => _room,
      voiceReady: () =>
          voicePhase == VoicePhase.connected ||
          voicePhase == VoicePhase.listener,
    )..addListener(notifyListeners);
    _voice = VoiceController(
      api,
      _session.scope,
      _audioDevices,
      _screen,
      readUser: () => user,
      reportError: (value) => error = value,
      formatError: _message,
      roomFactory: voiceRoomFactory,
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
  late final ScreenShareController _screen;
  late final VoiceController _voice;
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
  VoicePhase get voicePhase => _voice.voicePhase;
  set voicePhase(VoicePhase value) => _voice.voicePhase = value;
  GuildChannel? get voiceChannel => _voice.voiceChannel;
  set voiceChannel(GuildChannel? value) => _voice.voiceChannel = value;
  bool get microphoneMuted => _voice.microphoneMuted;
  set microphoneMuted(bool value) => _voice.microphoneMuted = value;
  bool get microphoneUnavailable => _voice.microphoneUnavailable;
  set microphoneUnavailable(bool value) => _voice.microphoneUnavailable = value;
  bool get deafened => _voice.deafened;
  set deafened(bool value) => _voice.deafened = value;
  bool get deafenChanging => _voice.deafenChanging;
  set deafenChanging(bool value) => _voice.deafenChanging = value;
  bool get voiceStreamSoundEnabled => _voice.voiceStreamSoundEnabled;
  set voiceStreamSoundEnabled(bool value) =>
      _voice.voiceStreamSoundEnabled = value;
  bool get voiceStreamStartNotice => _voice.voiceStreamStartNotice;
  set voiceStreamStartNotice(bool value) =>
      _voice.voiceStreamStartNotice = value;
  AudioActivationMode get audioActivationMode => _voice.audioActivationMode;
  set audioActivationMode(AudioActivationMode value) =>
      _voice.audioActivationMode = value;
  int? get pushToTalkKeyId => _voice.pushToTalkKeyId;
  set pushToTalkKeyId(int? value) => _voice.pushToTalkKeyId = value;
  String? get pushToTalkKeyLabel => _voice.pushToTalkKeyLabel;
  set pushToTalkKeyLabel(String? value) => _voice.pushToTalkKeyLabel = value;
  String? get audioActivationError => _voice.audioActivationError;
  set audioActivationError(String? value) =>
      _voice.audioActivationError = value;
  bool get pushToTalkPressed => _voice.pushToTalkPressed;
  set pushToTalkPressed(bool value) => _voice.pushToTalkPressed = value;
  Room? get _room => _voice.room;
  set _room(Room? value) => _voice.room = value;
  int? get _voicePingMs => _voice.voicePingMs;
  set _voiceVolumePreferences(VoiceVolumePreferences? value) =>
      _voice.voiceVolumePreferences = value;
  set _leaseId(String? value) => _voice.leaseId = value;
  set _listenerOnly(bool value) => _voice.listenerOnly = value;
  Timer? get _voiceStreamNoticeTimer => _voice.voiceStreamNoticeTimer;
  Set<String> get _mutedScreenShareAudioIdentities =>
      _voice.mutedScreenShareAudioIdentities;
  set _audioPreferences(AudioPreferences? value) =>
      _audioDevices.preferences = value;
  ScreenSharePhase get screenSharePhase => _screen.phase;
  set screenSharePhase(ScreenSharePhase value) => _screen.phase = value;
  String? get screenShareError => _screen.error;
  set screenShareError(String? value) => _screen.error = value;
  Map<String, Uint8List> get screenThumbnails => _screen.thumbnails;
  ScreenShareQuality get screenShareQuality => _screen.quality;
  set screenShareQuality(ScreenShareQuality value) => _screen.quality = value;

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
  Timer? _maintenanceTimer;
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

  Future<void> refreshAudioDevices() => _audioDevices.refreshAudioDevices();

  Future<void> selectAudioInput(String deviceId) =>
      _audioDevices.selectAudioInput(deviceId);

  Future<void> selectAudioOutput(String deviceId) =>
      _audioDevices.selectAudioOutput(deviceId);

  Future<void> setAudioProcessing(AudioProcessingPreferences next) =>
      _audioDevices.setAudioProcessing(next);

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
    final ticket = _session.scope.capture();
    if (!ticket.isActive) return;
    await selectChannel(channel);
    if (!ticket.isActive) return;
    if (channel.kind != ChannelKind.voice || channel.admissionClosed) return;
    if (voiceChannel?.id == channel.id || voicePhase == VoicePhase.joining) {
      return;
    }
    if (voiceChannel != null) await leaveVoice();
    if (!ticket.isActive) return;
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
    _screen.dispose();
    _voice.dispose();
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

  Future<void> startScreenShare({
    String? sourceId,
    ScreenShareQuality? quality,
    VideoDimensions? sourceDimensions,
  }) => _screen.startScreenShare(
    sourceId: sourceId,
    quality: quality,
    sourceDimensions: sourceDimensions,
  );

  Future<void> stopScreenShare() => _screen.stopScreenShare();

  Future<void> updateScreenShareQuality(ScreenShareQuality quality) =>
      _screen.updateScreenShareQuality(quality);

  void _stopScreenShareMetrics() => _screen.stopSampling();

  Future<void> _loadVoiceStreamSoundPreference() =>
      _voice.loadVoiceStreamSoundPreference();
  Future<void> setVoiceStreamSoundEnabled(bool enabled) =>
      _voice.setVoiceStreamSoundEnabled(enabled);
  void _clearVoiceStreamNotice({
    required bool resetTracker,
    required bool notify,
  }) =>
      _voice.clearVoiceStreamNotice(resetTracker: resetTracker, notify: notify);
  Future<void> _loadAudioPreferences(String accountId) =>
      _voice.loadAudioPreferences(accountId);
  Future<void> setPushToTalkKey(int? keyId, String? label) =>
      _voice.setPushToTalkKey(keyId, label);
  Future<void> setAudioActivationMode(AudioActivationMode next) =>
      _voice.setAudioActivationMode(next);
  Future<void> setPushToTalkPressed(bool pressed) =>
      _voice.setPushToTalkPressed(pressed);
  void _dispatchVoiceRevocation(Map<String, dynamic> payload) =>
      _voice.dispatchVoiceRevocation(payload);
  void _stopVoiceConnectionStatsPolling() =>
      _voice.stopVoiceConnectionStatsPolling();
  void _closeScreenPreviewSubscriptions() =>
      _voice.closeScreenPreviewSubscriptions();
  Future<void> _disposeVoiceEvents() => _voice.disposeVoiceEvents();
  Future<void> selectRemoteScreenForViewing(String? identity) =>
      _voice.selectRemoteScreenForViewing(identity);
  Future<void> joinVoice(GuildChannel channel, {bool listenerOnly = false}) =>
      _voice.joinVoice(channel, listenerOnly: listenerOnly);
  RemoteParticipant? voiceParticipantForAccount(String id) =>
      _voice.voiceParticipantForAccount(id);
  int? participantVolume(RemoteParticipant participant) =>
      _voice.participantVolume(participant);
  int? screenShareVolume(RemoteParticipant participant) =>
      _voice.screenShareVolume(participant);
  bool screenShareAudioMuted(RemoteParticipant participant) =>
      _voice.screenShareAudioMuted(participant);
  Future<void> setScreenShareAudioMuted(
    RemoteParticipant participant,
    bool muted,
  ) => _voice.setScreenShareAudioMuted(participant, muted);
  Future<void> setParticipantVolume(
    RemoteParticipant participant,
    num percent,
  ) => _voice.setParticipantVolume(participant, percent);
  Future<void> setScreenShareVolume(
    RemoteParticipant participant,
    num percent,
  ) => _voice.setScreenShareVolume(participant, percent);
  Future<void> toggleMicrophone() => _voice.toggleMicrophone();
  Future<void> toggleDeafen() => _voice.toggleDeafen();
  Future<void> leaveVoice() => _voice.leaveVoice();

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
