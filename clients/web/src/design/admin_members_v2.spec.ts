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

  it('uses the handoff typography for the mobile directory', () => {
    const css = readFileSync(new URL('./design_v2_admin_members.css', import.meta.url), 'utf8')
    expect(css).toContain('.admin-panel--members .admin-panel-heading h1 { font-size: 24px; line-height: 32px; font-weight: 600; }')
    expect(css).toContain('.admin-panel--members .admin-section-heading h2 { font-size: 20px; line-height: 28px; font-weight: 600; }')
    expect(css).toContain('.admin-panel--members .admin-mobile-user strong { font-size: 16px; line-height: 20px; font-weight: 600; }')
    const header = readFileSync(new URL('./design_v2_admin_permissions.css', import.meta.url), 'utf8')
    expect(header).toContain('.settings-workspace-header .workspace-header-toggle--nav, .settings-workspace-close { width: 44px; height: 44px; }')
  })

  it('uses the handoff SVG action mark on the live mobile account cards', () => {
    const css = readFileSync(new URL('./design_v2_admin_members.css', import.meta.url), 'utf8')
    expect(members).toContain('class="admin-mobile-menu-mark"')
    expect(members).toContain('<circle cx="5" cy="12" r="1"')
    expect(members).toContain('<circle cx="12" cy="12" r="1"')
    expect(members).toContain('<circle cx="19" cy="12" r="1"')
    expect(css).toContain('.admin-panel--members .admin-mobile-menu-mark')
    expect(css).not.toContain("content: '⋯'")
  })
})
