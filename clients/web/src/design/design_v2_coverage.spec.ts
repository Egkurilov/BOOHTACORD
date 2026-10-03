import { existsSync, readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const inventory = JSON.parse(readFileSync(new URL('../../artifacts/design-v2/reference-inventory.json', import.meta.url), 'utf8')) as {
  items: Array<{ id: string; state: string; viewport: { width: number; height: number } }>
}

const mapping: Record<string, string[]> = {
  'R01-R03': ['../workspace/WorkspaceApp.vue', '../workspace/WorkspaceMain.vue', '../conversation/TextConversation.vue', '../voice/VoiceDock.vue'],
  'R04-R05': ['../voice/ScreenViewer.vue', '../voice/VoiceDock.vue'],
  'R06-R07': ['../admin/role_permissions/AdminRolePermissions.vue'],
  'R08-R09,R24,R29': ['../channel/member_topology/ChannelTopologyActions.vue', '../channel/AdminCategoryControls.vue'],
  'R10-R11': ['../voice/AudioSettings.vue'],
  R12: ['../identity/ProfileSettings.vue'],
  R13: ['../workspace/search/WorkspaceSearchPanel.vue'],
  R14: ['../workspace/WorkspaceApp.vue'],
  R15: ['./foundation.css'],
  'R16-R17': ['../identity/AuthenticationLanding.vue', '../identity/PasswordResetCompletion.vue'],
  R18: ['../workspace/WorkspaceMembersPanel.vue', '../workspace/MemberPopover.vue'],
  R19: ['../voice/ScreenViewer.vue', '../voice/ScreenReceiverDiagnosticsPanel.vue'],
  R20: ['../voice/ScreenShareSetupDialog.vue'],
  'R21-R22': ['../admin/panel/AdminPanel.vue', '../admin/members/AdminMembersSection.vue'],
  R23: ['../updates/UpdateBanner.vue'],
  R25: ['../conversation/TextConversation.vue', '../conversation/MessageItem.vue', '../conversation/MentionPicker.vue'],
  R26: ['../conversation/PublishedAttachmentCard.vue', '../conversation/ProtectedImageViewer.vue'],
  R27: ['../workspace/WorkspaceMembersPanel.vue', '../voice/VoiceParticipantVolumes.vue'],
  R28: ['../direct_message/DirectMessageNavigation.vue', '../direct_message/DirectMessageConversation.vue', '../direct_message/DirectMessageStarter.vue'],
  R30: ['../voice/ScreenShareSetupDialog.vue'],
}

describe('Design V2 all-frame reference map', () => {
  it('contains every live HTML reference at its declared viewport', () => {
    expect(inventory.items.map(({ id }) => id)).toEqual(Array.from({ length: 30 }, (_, index) => `R${String(index + 1).padStart(2, '0')}`))
    expect(inventory.items.every(({ viewport }) => viewport.width > 0 && viewport.height > 0)).toBe(true)
  })

  it('maps each reference family to existing production Vue owners or the shared component system', () => {
    const mapped = Object.values(mapping).flat()
    expect(mapped.every((path) => existsSync(new URL(path, import.meta.url)))).toBe(true)
    expect(new Set(Object.keys(mapping)).size).toBe(20)
  })

  it('keeps the mobile admin card controls on the same save and reset workflows', () => {
    const members = readFileSync(new URL('../admin/members/AdminMembersSection.vue', import.meta.url), 'utf8')
    expect(members.match(/@click="save\(account, \$event\)"/g)).toHaveLength(2)
    expect(members.match(/@click="createReset\(account, \$event\)"/g)).toHaveLength(2)
  })

  it('keeps each new style layer below the project hard file-size limit', () => {
  for (const file of ['design_v2_chat.css', 'design_v2_foundation.css', 'design_v2_settings.css', 'design_v2_media.css', 'design_v2_overlays.css', 'design_v2_identity.css', 'design_v2_audio.css']) {
      expect(readFileSync(new URL(`./${file}`, import.meta.url), 'utf8').split('\n').length).toBeLessThanOrEqual(120)
    }
  })
})
