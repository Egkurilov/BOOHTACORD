import { readFileSync } from 'node:fs'
import { expect, it } from 'vitest'

it.each([
  ['../../conversation/TextMessageSearch.vue','../../conversation/TextConversation.vue','CHANNEL','channelId'],
  ['../../direct_message/DirectMessageSearch.vue','../../direct_message/DirectMessageConversation.vue','DIRECT_MESSAGE','directMessageId'],
])('routes local result IDs through the protected shared context: %s', (picker, conversation, kind, scope) => {
  const search = readFileSync(new URL(picker,import.meta.url),'utf8')
  const parent = readFileSync(new URL(conversation,import.meta.url),'utf8')
  expect(search).toContain("emit('open', message.id)")
  expect(parent).toContain(`searchTarget.open({ kind: '${kind}', conversationId: props.${scope}, messageId: $event })`)
  expect(parent).toContain('v-show="!contextOpen()" class="conversation-tools"')
})
