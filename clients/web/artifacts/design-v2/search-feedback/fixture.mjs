import { chatMembers, chatProfile, chatTopology } from '../chat-reference-fixture.mjs'
import { installReferenceTransports } from '../reference-live-state.mjs'

const channelId = '11111111-1111-4111-8111-111111111111'
const authorId = '22222222-2222-4222-8222-222222222221'
const message = { id: '33333333-3333-4333-8333-333333333333', kind: 'CHANNEL', channel_id: channelId,
  author_id: authorId, body: 'Тестовый результат поиска', created_at: '2026-10-03T16:00:00Z', revision: 1 }
const topology = { ...chatTopology, categories: chatTopology.categories.map(category => ({ ...category,
  channels: category.channels.map(channel => channel.id === 'text-1' ? { ...channel, id: channelId } : channel) })) }

export async function installFixture(page) {
  let release, requested = 0
  await installReferenceTransports(page)
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname
    let body = {}, status = 200
    if (path.endsWith('/search/messages')) {
      requested++
      const mode = await new Promise(resolve => { release = resolve })
      body = mode === 'error' ? { error: { code: 'internal_error' } } : { messages: mode === 'results' ? [message] : [] }
      if (mode === 'error') status = 500
    } else if (path.endsWith('/auth/session')) body = { account_id: chatProfile.account_id, role: chatProfile.role }
    else if (path.endsWith('/auth/permissions')) body = { account_id: chatProfile.account_id, role: chatProfile.role, permissions_revision: 1, permissions: {} }
    else if (path.endsWith('/me')) body = chatProfile
    else if (path.endsWith('/channels')) body = topology
    else if (path.endsWith('/members')) body = { members: chatMembers }
    else if (path.includes('/members/')) body = { ...chatMembers[0], user_id: authorId }
    else if (path.endsWith('/direct-messages')) body = { direct_messages: [] }
    else if (path.includes('/messages')) body = { messages: [] }
    else if (path.includes('/read-cursor')) body = { message_id: null }
    else if (path.includes('/maintenance')) body = { active: false }
    else if (path.includes('/client-updates')) body = { state: 'unconfigured', target: null }
    await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) })
  })
  return { requests: () => requested, finish: mode => { release?.(mode); release = undefined } }
}
