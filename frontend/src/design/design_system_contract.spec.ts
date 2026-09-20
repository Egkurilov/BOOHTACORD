import { describe, expect, it } from 'vitest'

import { readFileSync } from 'node:fs'

import voiceDock from '../voice/VoiceDock.vue?raw'
import directConversation from '../direct_message/DirectMessageConversation.vue?raw'
import directNavigation from '../direct_message/DirectMessageNavigation.vue?raw'
import directStarter from '../direct_message/DirectMessageStarter.vue?raw'
import messageItem from '../conversation/MessageItem.vue?raw'
import messageBody from '../conversation/MessageBody.vue?raw'
import attachmentPicker from '../conversation/TextMessageAttachmentPicker.vue?raw'
import messageAttachments from '../conversation/TextMessageAttachments.vue?raw'
import conversationPane from '../conversation/ConversationPane.vue?raw'
import screenViewer from '../voice/ScreenViewer.vue?raw'
import textConversation from '../conversation/TextConversation.vue?raw'
import workspace from '../workspace/WorkspaceApp.vue?raw'
import membersPanel from '../workspace/WorkspaceMembersPanel.vue?raw'

function source(relativePath: string): string {
  return readFileSync(new URL(relativePath, import.meta.url), 'utf8')
}

describe('GuildChat design-system foundation', () => {
  it('keeps the supplied dark tokens and motion guard', () => {
    const tokens = source('./tokens.css')
    const foundation = source('./foundation.css')

    expect(tokens).toContain('--gc-canvas: #0E1117')
    expect(tokens).toContain('--gc-accent: #5C5FE8')
    expect(tokens).toContain('--gc-layout-nav-wide: 312px')
    expect(tokens).toContain('--gc-layout-aside-wide: 312px')
    expect(foundation).toContain('prefers-reduced-motion: reduce')
  })

  it('keeps the supplied wide, medium, and compact shell breakpoints', () => {
    const shell = source('./shell.css')

    expect(shell).toContain('@media (min-width: 1440px)')
    expect(shell).toContain('@media (min-width: 1280px) and (max-width: 1439px)')
    expect(shell).toContain('@media (min-width: 1024px) and (max-width: 1279px)')
    expect(shell).toContain('@media (max-width: 1023px)')
  })

  it('retains labelled app shell regions and a persistent voice dock', () => {
    expect(workspace).toContain('data-testid="app-shell"')
    expect(workspace).toContain('data-testid="main-region"')
    expect(workspace).toContain("'no-aside'")
    expect(membersPanel).toContain('data-testid="members-panel"')
    expect(voiceDock).toContain('data-testid="voice-dock"')
  })

  it('keeps conversations on the shared token contract', () => {
    for (const component of [textConversation, directConversation, messageItem]) {
      expect(component).not.toContain('<style scoped>')
      expect(component).not.toContain('#222836')
    }
  })

  it('renders a roster from only live voice participants and shares component paint rules', () => {
    expect(membersPanel).toContain('VoiceVolumeParticipant[]')
    expect(membersPanel).toContain('v-for="participant in participants"')
    for (const component of [directNavigation, directStarter, messageBody, attachmentPicker, messageAttachments]) {
      expect(component).not.toContain('<style scoped>')
    }
  })

  it('uses data-derived monograms for messages and direct-message navigation', () => {
    expect(messageItem).toContain('class="message-avatar"')
    expect(directNavigation).toContain('class="dm-avatar"')
  })

  it('keeps the preview hierarchy for chat, voice, and stream surfaces', () => {
    expect(workspace).toContain('class="gc-shell"')
    expect(workspace).toContain('class="sidebar"')
    expect(workspace).toContain('class="nav-content"')
    expect(textConversation).toContain('class="main-header conversation-header"')
    expect(textConversation).toContain('class="messages message-list"')
    expect(textConversation).toContain('class="composer-wrap"')
    expect(directConversation).toContain('class="main-header conversation-header"')
    expect(workspace).toContain('<WorkspaceSidebarTabs')
    expect(conversationPane).toContain('class="room-intro"')
    expect(screenViewer).toContain('class="stream-controls"')
  })
})
