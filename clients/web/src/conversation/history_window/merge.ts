import type { Ref } from 'vue'

import { trackRealtimeMessages } from '../../telemetry/realtime_flow/process'
import type { TextMessage } from '../message_client'
import { indexMessages } from '../message_index/index'
import { pendingMessage, type PendingSend } from './pending'

export function createHistoryMerger(
  messages: Ref<TextMessage[]>,
  channelId: Ref<string | null>,
  pending: Map<string, PendingSend>,
) {
  return (incoming: TextMessage[]): void => {
    const byId = new Map(indexMessages(messages.value.filter((item) => !item.sendStatus)))
    for (const message of incoming) {
      const current = byId.get(message.id)
      if (!current || message.revision >= current.revision) byId.set(message.id, message)
    }
    const server = [...byId.values()].sort(
      (left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt) ||
        right.id.localeCompare(left.id),
    )
    const acknowledged = new Set(server.map(({ clientMessageId }) => clientMessageId))
    const queued = [...pending].flatMap(([id, draft]) => {
      if (draft.channelId !== channelId.value) return []
      if (acknowledged.has(id)) {
        pending.delete(id)
        return []
      }
      return [pendingMessage(id, draft)]
    })
    messages.value = [...queued, ...server]
    trackRealtimeMessages(incoming)
  }
}
