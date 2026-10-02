import { useMessageStore } from '../conversation/message_store'
import { useVoiceConnectionStore } from '../voice/connection_store'

function editedFields(): boolean {
  return [...document.querySelectorAll<HTMLInputElement | HTMLTextAreaElement>('textarea, input[type="text"]')]
    .some((field) => field.value.trim().length > 0 && !field.readOnly)
}

export function reloadRisks(): string[] {
  const voice = useVoiceConnectionStore(); const messages = useMessageStore()
  const risks: string[] = []
  if (editedFields()) risks.push('есть несохранённый текст')
  if (messages.sending || document.querySelector('[aria-busy="true"]')) risks.push('выполняется отправка или загрузка')
  if (!['IDLE', 'ERROR'].includes(voice.state)) risks.push('активно голосовое подключение')
  if (voice.screenState !== 'IDLE') risks.push('активна демонстрация экрана')
  return risks
}

export async function controlledReload(expectedRelease: string): Promise<void> {
  const risks = reloadRisks()
  if (risks.length && !window.confirm(`Перед обновлением: ${risks.join(', ')}. Завершить активные действия и перезагрузить?`)) return
  const voice = useVoiceConnectionStore()
  if (voice.screenState !== 'IDLE') await voice.stopScreen()
  if (!['IDLE', 'ERROR'].includes(voice.state)) await voice.leave()
  sessionStorage.setItem('boohtacord:update-attempt', JSON.stringify({ expectedRelease, attemptedAt:Date.now() }))
  window.location.reload()
}
