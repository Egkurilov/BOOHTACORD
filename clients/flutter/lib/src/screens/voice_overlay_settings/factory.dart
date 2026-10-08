import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../app/overlay_preferences/actions.dart';
import '../../features/voice/overlay/settings/model.dart';
import 'component.dart';

Future<void> showVoiceOverlaySettings(
  BuildContext context,
  AppState state,
) async {
  final current =
      state.voiceOverlayPreferences?.configuration ??
      const OverlayConfiguration();
  await showDialog<void>(
    context: context,
    builder: (_) => VoiceOverlaySettingsDialog(
      initial: current,
      save: state.saveOverlayConfiguration,
    ),
  );
}

Future<void> toggleVoiceOverlayEditing(AppState state) async {
  final client = state.voiceOverlayWindowsClient;
  if (client == null || !state.voiceOverlay.enabled) return;
  final accepted = await client.configuration.configure(
    client.configuration.current,
    edit: !client.configuration.editing,
  );
  if (!accepted) state.error = 'Не удалось включить режим перемещения панели.';
  state.notifyListeners();
}
