import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../services/api_client.dart';
import '../../services/native_notifications.dart';
import '../../features/session/lifecycle/controller.dart';
import '../../features/session/reset_state/controller.dart';
import '../../features/session/maintenance_state/controller.dart';
import '../../features/profile/state/controller.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../../features/conversation/lifecycle/controller.dart';
import '../../features/realtime/lifecycle/controller.dart';
import '../../features/audio/devices/controller.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/voice/roster_state/controller.dart';
import '../../features/screen/lifecycle/controller.dart';
import '../../features/authorization/permissions/controller.dart';
import '../../features/guild/profile/controller.dart';

abstract class AppOwners extends ChangeNotifier {
  AppOwners(
    this.api, {
    this.startupSessionTimeout = const Duration(seconds: 20),
    this.voiceRosterRetryDelay = const Duration(seconds: 2),
    this.voiceRosterStaleTimeout = const Duration(seconds: 10),
    this.audioDeviceLoader,
    this.audioDeviceChanges,
    this.audioDeviceBootstrap,
    this.voiceRoomFactory,
    NativeNotificationService? nativeNotifications,
  }) : nativeNotifications = nativeNotifications ?? NativeNotificationService();
  final ApiClient api;
  final Duration startupSessionTimeout;
  final Duration voiceRosterRetryDelay;
  final Duration voiceRosterStaleTimeout;
  final Future<List<MediaDevice>> Function()? audioDeviceLoader;
  final Stream<List<MediaDevice>>? audioDeviceChanges;
  final Future<void> Function()? audioDeviceBootstrap;
  final Room Function(RoomOptions)? voiceRoomFactory;
  final NativeNotificationService nativeNotifications;
  late final SessionController session;
  late final GuildProfileController guildProfile;
  late final PasswordResetController reset;
  late final MaintenanceController maintenance;
  late final ProfileController profileOwner;
  late final WorkspaceController workspace;
  late final ConversationController conversation;
  late final RealtimeController realtime;
  late final AudioDeviceController audioDevices;
  late final VoiceController voice;
  late final VoiceRosterController voiceRoster;
  late final ScreenShareController screen;
  late final PermissionController permissions;
  String? error;
  bool disposed = false;
  @override
  void notifyListeners() {
    if (!disposed) super.notifyListeners();
  }
}
