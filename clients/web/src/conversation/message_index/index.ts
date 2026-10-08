import type { TextMessage } from '../message_client'

export function indexMessages(messages: readonly TextMessage[]): ReadonlyMap<string, TextMessage> {
  return new Map(messages.map((message) => [message.id, message]))
}
