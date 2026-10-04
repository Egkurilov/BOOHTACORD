import '../lifecycle/controller.dart';
extension VoiceDisconnectControl on VoiceController {
  void showVoiceDisconnect() {
    final notice = disconnect.notice;
    if (notice == null) return;
    voicePhase = notice.source == 'local' ? VoicePhase.idle : VoicePhase.error;
    error = notice.source == 'local' ? null : notice.message;
    notifyListeners();
  }
  void selectDisconnectChannel(String channelId) {
    final old = disconnect.notice;
    disconnect.selectChannel(channelId);
    if (old != null && disconnect.notice == null) { error = null; notifyListeners(); }
  }
}
