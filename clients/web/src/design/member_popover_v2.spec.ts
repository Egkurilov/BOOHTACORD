import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import popover from '../workspace/MemberPopover.vue?raw'
import members from '../workspace/WorkspaceMembersPanel.vue?raw'

describe('V2 member popover', () => {
  it('shows the live member identity and keeps its real actions unclipped', () => {
    expect(popover).toContain('avatarBackground(props.memberID)')
    expect(popover).toContain("emit('openDM', member.user_id)")
    expect(members).toContain("'has-popover': Boolean(selectedID)")
    expect(readFileSync(new URL('./design_v2_member_popover.css', import.meta.url), 'utf8')).toContain('.members-panel.has-popover')
  })
})
