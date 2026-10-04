import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import popover from '../workspace/MemberPopover.vue?raw'
import members from '../workspace/WorkspaceMembersPanel.vue?raw'
const css = readFileSync(new URL('./design_v2_member_popover.css', import.meta.url), 'utf8')

describe('V2 member popover', () => {
  it('shows the live member identity and keeps its real actions unclipped', () => {
    expect(popover).toContain('avatarBackground(props.memberID)')
    expect(popover).toContain("emit('openDM', member.user_id)")
    expect(members).toContain("'has-popover': Boolean(selectedID)")
    expect(css).toContain('.members-panel.has-popover')
  })

  it('uses a modal mobile sheet with restored focus and an ID-based avatar', () => {
    expect(popover).toContain(':aria-modal="props.modal ?')
    expect(popover).toContain('avatarInitials(member.display_name)')
    expect(popover).toContain(':title="member.display_name"')
    expect(members).toContain('class="member-sheet-scrim"')
    expect(members).toContain('<MemberPopover v-if="selectedID" :key="selectedID"')
    expect(members).toContain('trigger.value?.focus()')
    expect(css).toContain('.members-panel .member-popover { position: fixed;')
  })

  it('retains the existing profile API, DM, volume and scoped kick actions', () => {
    for (const expected of ['loadMember', 'Escape', 'openDM', 'setVolume', 'kickVoiceParticipant']) expect(popover).toContain(expected)
  })
})
