import { chatMembers, chatProfile, chatTopology } from '../chat-reference-fixture.mjs'
import { installReferenceTransports } from '../reference-live-state.mjs'

export async function installFixture(page) {
  const mutations = []
  await installReferenceTransports(page)
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname
    if (!['GET', 'HEAD'].includes(route.request().method())) mutations.push(route.request().method())
    let body = {}
    if (path.endsWith('/auth/session')) body = { account_id: chatProfile.account_id, role: chatProfile.role }
    else if (path.endsWith('/auth/permissions')) body = { account_id: chatProfile.account_id, role: chatProfile.role,
      permissions_revision: 1, permissions: { 'category.create': true, 'channel.text.create': true, 'channel.voice.create': true,
        'category.delete': false, 'channel.text.delete': false, 'channel.voice.delete': false } }
    else if (path.endsWith('/me')) body = chatProfile
    else if (path.endsWith('/channels')) body = chatTopology
    else if (path.endsWith('/members')) body = { members: chatMembers }
    else if (path.includes('/members/')) body = chatMembers.find(member => path.endsWith(`/${member.user_id}`)) ?? {}
    else if (path.endsWith('/direct-messages')) body = { direct_messages: [] }
    else if (path.includes('/messages')) body = { messages: [] }
    else if (path.includes('/read-cursor')) body = { message_id: null }
    else if (path.includes('/maintenance')) body = { active: false }
    else if (path.includes('/client-updates')) body = { state: 'unconfigured', target: null }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
  })
  return mutations
}
