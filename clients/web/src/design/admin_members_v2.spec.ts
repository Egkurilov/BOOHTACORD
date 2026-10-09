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
    expect(css).toContain('.admin-panel--members .admin-panel-heading h1 { font-size: var(--gc-text-page); line-height: var(--gc-line-page); font-weight: var(--gc-weight-semibold); }')
    expect(css).toContain('.admin-panel--members .admin-section-heading h2 { font-size: var(--gc-text-section); line-height: var(--gc-line-section); font-weight: var(--gc-weight-semibold); }')
    expect(css).toContain('.admin-panel--members .admin-mobile-user strong { font-size: 16px; line-height: 20px; font-weight: 600; }')
    const header = readFileSync(new URL('../shared/workspace_header/settings_header.css', import.meta.url), 'utf8')
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

  it('aligns mobile search and account status geometry with R22', () => {
    const css = readFileSync(new URL('./design_v2_admin_members.css', import.meta.url), 'utf8')
    expect(css).toContain('.admin-member-filters select { width: 81px;')
    expect(css).toContain('background: var(--gc-sidebar); font-size: 14px;')
    expect(css).toContain('.admin-panel--members .admin-mobile-meta .is-active { border-radius: 4px; padding: 2px 6px; color: #78e6a0; background: #123320; font-size: 12px; font-weight: 600; line-height: 16px; }')
    expect(css).toContain('.admin-account-status { border-radius: 4px; padding: 2px 6px; font-size: 12px; font-weight: 600; line-height: 16px; }')
    expect(css).toContain('.admin-account-status.is-active { color: #78e6a0; background: #123320; }')
  })
})
