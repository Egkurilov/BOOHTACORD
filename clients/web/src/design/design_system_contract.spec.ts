import { describe, expect, it } from 'vitest'

import { readFileSync } from 'node:fs'

import voiceDock from '../voice/VoiceDock.vue?raw'
import directConversation from '../direct_message/DirectMessageConversation.vue?raw'
import directHistoryList from '../direct_message/DirectMessageHistoryList.vue?raw'
import directNavigation from '../direct_message/DirectMessageNavigation.vue?raw'
import directStarter from '../direct_message/DirectMessageStarter.vue?raw'
import messageItem from '../conversation/MessageItem.vue?raw'
import messageBody from '../conversation/MessageBody.vue?raw'
import attachmentPicker from '../conversation/TextMessageAttachmentPicker.vue?raw'
import messageAttachments from '../conversation/TextMessageAttachments.vue?raw'
import conversationPane from '../conversation/ConversationPane.vue?raw'
import screenViewer from '../voice/ScreenViewer.vue?raw'
import textConversation from '../conversation/TextConversation.vue?raw'
import textHistoryList from '../conversation/TextHistoryList.vue?raw'
import workspace from '../workspace/WorkspaceApp.vue?raw'
import workspaceMain from '../workspace/WorkspaceMain.vue?raw'
import membersPanel from '../workspace/WorkspaceMembersPanel.vue?raw'
import profileSettings from '../identity/ProfileSettings.vue?raw'
import adminPanel from '../admin/panel/AdminPanel.vue?raw'
import memberPopover from '../workspace/MemberPopover.vue?raw'

function source(relativePath: string): string {
  return readFileSync(new URL(relativePath, import.meta.url), 'utf8')
}

describe('GuildChat design-system foundation', () => {
  it('keeps the supplied dark tokens and motion guard', () => {
    const tokens = source('./tokens.css')
    const foundation = source('./foundation.css')

    expect(tokens).toContain('--gc-canvas: #0E1117')
    expect(tokens).toContain('--gc-accent: #5C5FE8')
    expect(tokens).toContain('--gc-layout-nav-wide: 280px')
    expect(tokens).toContain('--gc-layout-aside-wide: 248px')
    expect(tokens).toContain('--gc-layout-frame-wide: 0px')
    expect(foundation).toContain('prefers-reduced-motion: reduce')
  })

  it('keeps the supplied wide, medium, and compact shell breakpoints', () => {
    const shell = source('./shell.css') + source('./responsive_shell.css')

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
    for (const component of [textConversation, textHistoryList, directConversation, directHistoryList, messageItem]) {
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
    expect(textConversation).toContain('<TextHistoryList')
    expect(textHistoryList).toContain('class="messages message-list"')
    expect(textConversation).toContain('class="composer-wrap"')
    expect(directConversation).toContain('class="main-header conversation-header"')
    expect(directConversation).toContain('<DirectMessageHistoryList')
    expect(directHistoryList).toContain('class="messages message-list"')
    expect(workspace).toContain('<WorkspaceSidebarTabs')
    expect(conversationPane).toContain('class="room-intro"')
    expect(screenViewer).toContain('class="stream-quality-row"')
    expect(screenViewer).toContain('class="screen-cards stream-rail"')
  })

  it('keeps settings and administration in the central workspace', () => {
    expect(workspace).toContain("'no-aside': (activePanel === 'search' && voiceStageWide) || (activePanel !== 'search' && (voiceStageWide || selectedDirectMessage || activePanel !== 'none'))")
    expect(workspace).toContain('<template #admin>')
    expect(workspace).toContain('<template #audio>')
    expect(workspace).toContain('<template #profile>')
    expect(workspace).toContain('<AdminPanel')
    expect(workspace).toContain('<ChannelTopologyActions')
    expect(workspaceMain).toContain('<slot name="admin" />')
    expect(workspaceMain).toContain('<slot name="audio" />')
    expect(workspaceMain).toContain('workspace-main-panel')
    const settingsStyles = source('./settings.css')
    expect(settingsStyles).toContain('max-width: 720px')
    expect(settingsStyles).toContain('max-width: 1120px')
    expect(settingsStyles).toContain('.admin-topology-form { display: grid;')
    expect(settingsStyles).toContain('grid-template-columns: repeat(2, minmax(0, 1fr))')
  })
  it('connects profile settings and admin tabs to real API workflows', () => {
    for (const expected of ['readonly', 'current-password', 'new-password', 'uploadAvatar', 'changeOwnPassword', 'aria-live']) expect(profileSettings).toContain(expected)
    for (const expected of ['Участники', 'Каналы', 'Аудит', 'AdminMembersSection', 'AdminAuditSection']) expect(adminPanel).toContain(expected)
  })

  it('keeps the nonmodal member profile actions scoped to existing APIs', () => {
    for (const expected of ['aria-modal="false"', 'Escape', 'loadMember', 'openDM', 'setVolume', 'kickVoiceParticipant']) expect(memberPopover).toContain(expected)
  })
})
