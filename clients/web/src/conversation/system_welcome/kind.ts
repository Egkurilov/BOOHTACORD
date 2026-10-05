export type MessageKind = 'USER' | 'SYSTEM_WELCOME'
export function parseMessageKind(value: unknown): MessageKind {
  if (value === undefined || value === 'USER') return 'USER'
  if (value === 'SYSTEM_WELCOME') return value
  throw new Error('Некорректный тип сообщения.')
}
