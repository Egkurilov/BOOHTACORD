import { voiceLeaseRevocationMessage, type VoiceLeaseRevocationReason } from '../voice_lease_revocation_reason'
export type DisconnectSource = 'server' | 'local' | 'transport'
export interface VoiceDisconnectNotice { reason: VoiceLeaseRevocationReason | 'TRANSPORT'; source: DisconnectSource; message: string; explanation: string; reconnectAllowed: boolean }
export function disconnectNotice(reason: VoiceDisconnectNotice['reason'], source: DisconnectSource): VoiceDisconnectNotice {
  const reconnectAllowed = !['CHANNEL_CLOSED', 'BANNED', 'SESSION_REVOKED', 'LOGOUT'].includes(reason)
  const explanation = reason === 'KICK' ? 'Автоматическое переподключение остановлено. Вы можете подключиться снова вручную.'
    : reason === 'CHANNEL_CLOSED' ? 'Подключение к этому каналу недоступно.'
    : reason === 'BANNED' ? 'Подключение к гильдии недоступно.'
    : reason === 'SESSION_REVOKED' || reason === 'LOGOUT' ? 'Войдите в аккаунт снова.'
    : reason === 'TRANSFER' ? 'Подключение перенесено на другое устройство или окно.'
    : reason === 'TRANSPORT' ? 'Проверьте связь и подключитесь снова вручную.' : ''
  return { reason, source, reconnectAllowed, explanation, message: reason === 'TRANSPORT' ? 'Голосовое соединение не восстановлено. Подключитесь снова вручную.' : voiceLeaseRevocationMessage(reason) }
}
