import '../../../services/voice_lease_revocation.dart';
class VoiceDisconnectNotice {
  VoiceDisconnectNotice(this.reason, this.source, {String? transportMessage})
      : message = reason == 'TRANSPORT' ? transportMessage ?? 'Связь с голосовым каналом потеряна. Подключитесь ещё раз.' : VoiceLeaseRevocation(leaseId: '', reason: reason).message;
  final String reason, source, message;
  bool get reconnectAllowed => !{'CHANNEL_CLOSED', 'BANNED', 'SESSION_REVOKED', 'LOGOUT'}.contains(reason);
  String get explanation => switch (reason) {
    'KICK' => 'Автоматическое переподключение остановлено. Вы можете подключиться снова вручную.',
    'CHANNEL_CLOSED' => 'Подключение к этому каналу недоступно.',
    'BANNED' => 'Подключение к гильдии недоступно.',
    'SESSION_REVOKED' || 'LOGOUT' => 'Войдите в аккаунт снова.',
    'TRANSFER' => 'Подключение перенесено на другое устройство или окно.',
    'TRANSPORT' => 'Проверьте связь и подключитесь снова вручную.',
    _ => '',
  };
}
