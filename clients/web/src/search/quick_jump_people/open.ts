import type { TopologyChannel } from '../../channel/topology_client'
import { DirectMessageCandidateRequestError, openDirectMessage } from '../../direct_message/direct_message_candidate_client'
import type { QuickJumpTarget } from '../quick_jump'

interface Ports {
  channels(): TopologyChannel[]
  refreshChannels(): Promise<void>
  channelError(): boolean
  dialogs(): { id: string }[]
  refreshDialogs(): Promise<void>
  dialogError(): boolean
  channel(channel: TopologyChannel): void
  dialog(id: string): void
  error(message: string): void
}
export function createQuickJumpOpen(ports: Ports, openMember = openDirectMessage) {
  let sequence = 0, disposed = false, busy = false
  return {
    async open(entry: QuickJumpTarget): Promise<void> {
      if (disposed || busy) return
      const current = ++sequence
      const valid = () => !disposed && current === sequence
      busy = true; ports.error('')
      try {
        if (entry.kind === 'CHANNEL') {
          await ports.refreshChannels()
          if (!valid()) return
          const channel = ports.channels().find(item => item.id === entry.id && item.kind === 'TEXT')
          if (ports.channelError() || !channel) { ports.error('Текстовый канал больше недоступен.'); return }
          ports.channel(channel)
        } else {
          const id = entry.kind === 'MEMBER' ? (await openMember(entry.id)).id : entry.id
          if (!valid()) return
          await ports.refreshDialogs()
          if (!valid()) return
          if (ports.dialogError() || !ports.dialogs().some(dialog => dialog.id === id)) {
            ports.error('Личный диалог больше недоступен.'); return
          }
          ports.dialog(id)
        }
      } catch (cause) {
        if (!valid()) return
        if (cause instanceof DirectMessageCandidateRequestError &&
          (cause.status === 403 || cause.status === 404)) {
          ports.error('Личный диалог больше недоступен.')
        } else {
          ports.error('Не удалось открыть участника. Обновите список и повторите попытку.')
        }
      }
      finally { busy = false }
    },
    dispose() { disposed = true; sequence++ },
  }
}
