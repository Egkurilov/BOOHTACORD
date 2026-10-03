import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import panel from '../admin/panel/AdminPanel.vue?raw'
import members from '../admin/members/AdminMembersSection.vue?raw'

describe('V2 administrator member directory', () => {
  it('keeps the real account mutations behind a searchable table and mobile cards', () => {
    expect(panel).toContain("'admin-panel--members': section === 'members'")
    expect(members).toContain('filteredAccounts')
    expect(members).toContain('Поиск по имени или логину')
    expect(members).toContain('Все роли')
    expect(members).toContain('class="admin-account-actions-menu"')
    expect(members).toContain('updateAdminAccount')
    expect(members).toContain('createPasswordResetLink')
    expect(readFileSync(new URL('./design_v2_admin_members.css', import.meta.url), 'utf8')).toContain('.admin-panel--members')
  })
})
