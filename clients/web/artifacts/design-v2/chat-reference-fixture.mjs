// Synthetic API records for comparing the real chat components with R01–R03.
export const chatProfile = { account_id: 'egor-2', login: 'egor', display_name: 'Егор', role: 'ADMINISTRATOR' }
export const chatMembers = [
  { user_id: 'alex-3', login: 'alex', display_name: 'Alex', role: 'MEMBER', presence: 'online' },
  { user_id: 'daria-2', login: 'daria', display_name: 'Daria', role: 'MEMBER', presence: 'online' },
  { user_id: 'max-7', login: 'max', display_name: 'Max', role: 'MEMBER', presence: 'online' },
  { user_id: 'egor-2', login: 'egor', display_name: 'Егор', role: 'ADMINISTRATOR', presence: 'online' },
  { user_id: 'nika-3', login: 'nika', display_name: 'Nika', role: 'MEMBER', presence: 'offline' },
  { user_id: 'sergey-4', login: 'sergey', display_name: 'Сергей', role: 'MEMBER', presence: 'offline' },
]
const text = (id, name, position, mentionCount = 0) => ({ id, name, kind: 'TEXT', position, admission_closed: false, unread_count: 0, mention_count: mentionCount })
const voice = (id, name, position) => ({ id, name, kind: 'VOICE', position, admission_closed: false })
export const chatTopology = { revision: 1, categories: [
  { id: 'chat', name: 'ОБЩЕНИЕ', position: 0, channels: [text('text-1', 'общее', 0), text('games', 'игры', 1), { ...text('announcements', 'объявления', 2), unread_count: 2 }] },
  { id: 'voice', name: 'ГОЛОСОВЫЕ', position: 1, channels: [voice('voice-1', 'Общий', 0), voice('voice-2', 'Играем', 1)] },
  { id: 'development', name: 'РАЗРАБОТКА', position: 2, channels: [text('discussion', 'обсуждение', 0), text('ideas', 'идеи', 1)] },
] }
const message = (id, authorId, time, body, attachments = []) => ({
  id, channel_id: 'text-1', author_id: authorId, client_message_id: `fixture-${id}`, body,
  revision: 1, created_at: `2026-10-03T${time}:00Z`, deleted: false, attachments, mention_user_ids: [],
})
export const chatMessages = [
  message('chat-1', 'alex-3', '16:28', 'Кто сегодня играет вечером?'),
  message('chat-2', 'daria-2', '16:31', 'Я буду. Давайте соберёмся в 20:00.'),
  message('chat-3', 'max-7', '16:35', 'Скидываю скриншот прошлого катка.', [{ id: 'scene', original_name: 'evening-session.png', byte_size: 2_400_000 }]),
  message('chat-4', 'egor-2', '16:40', '@Daria Отлично, увидимся в голосовом!'),
]
