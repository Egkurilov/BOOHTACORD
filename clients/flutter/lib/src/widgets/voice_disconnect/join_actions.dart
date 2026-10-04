import 'package:flutter/material.dart';
import '../../features/voice/disconnect_notice/model.dart';
class VoiceManualJoinActions extends StatelessWidget {
  const VoiceManualJoinActions({super.key, required this.joining, required this.leaving,
    required this.admissionClosed, required this.onJoin, required this.onListen, this.notice});
  final bool joining, leaving, admissionClosed;
  final VoidCallback onJoin, onListen;
  final VoiceDisconnectNotice? notice;
  @override
  Widget build(BuildContext context) {
    final disabled = joining || leaving || admissionClosed || notice?.reconnectAllowed == false;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: disabled ? null : onJoin,
        icon: joining ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
        label: Text(admissionClosed ? 'Вход временно закрыт' : joining ? 'Подключаемся…' : 'Подключиться к голосу'),
      )),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: disabled ? null : onListen, icon: const Icon(Icons.headset_outlined),
        label: const Text('Подключиться без микрофона'),
      )),
    ]);
  }
}
