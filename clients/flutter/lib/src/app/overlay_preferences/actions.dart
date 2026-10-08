import 'dart:async';

import '../../features/voice/overlay/settings/model.dart';
import '../composition/owners.dart';

extension AppOverlayPreferences on AppOwners {
  Future<bool> saveOverlayConfiguration(OverlayConfiguration value) async {
    final revision = ++voiceOverlaySettingsRevision;
    final pref = voiceOverlayPreferences;
    final ticket = session.scope.capture();
    if (pref == null ||
        !ticket.isActive ||
        pref.accountId != session.user?.accountId) {
      return false;
    }
    if (!await pref.saveConfiguration(value)) return false;
    if (!ticket.isActive ||
        revision != voiceOverlaySettingsRevision ||
        !identical(pref, voiceOverlayPreferences)) {
      return false;
    }
    voiceOverlay.setMaxParticipants(value.maxParticipants);
    final accepted =
        await voiceOverlayWindowsClient?.configuration.configure(value) ??
        false;
    if (!ticket.isActive ||
        revision != voiceOverlaySettingsRevision ||
        !identical(pref, voiceOverlayPreferences)) {
      return false;
    }
    voiceOverlay.setEnabled(value.enabled);
    notifyListeners();
    return accepted;
  }

  void bindOverlayPlacement() {
    final client = voiceOverlayWindowsClient;
    final pref = voiceOverlayPreferences;
    if (client == null || pref == null) return;
    final ticket = session.scope.capture();
    client.configuration.onPlacement = (value) {
      if (!ticket.isActive || !identical(pref, voiceOverlayPreferences)) return;
      unawaited(pref.saveConfiguration(value));
      notifyListeners();
    };
    client.configuration.onHotkeyConflict = () {
      if (!ticket.isActive || !identical(pref, voiceOverlayPreferences)) return;
      error = 'Не удалось зарегистрировать горячую клавишу overlay. Возможно, она занята другим приложением. Выберите другую комбинацию.';
      notifyListeners();
    };
  }
}
