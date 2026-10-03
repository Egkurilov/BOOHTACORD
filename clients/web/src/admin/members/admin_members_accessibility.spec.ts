import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const screen = readFileSync(new URL('./AdminMembersSection.vue', import.meta.url), 'utf8')
const presentation = readFileSync(new URL('../../design/design_v2_admin_members.css', import.meta.url), 'utf8')
const visualFixture = readFileSync(new URL('../../../artifacts/design-v2/dom-probe.mjs', import.meta.url), 'utf8')

describe('administrator member row controls', () => {
  it('includes the account login in each repeated keyboard control name', () => {
    expect(screen).toContain(':aria-label="`Роль: ${account.login}`"')
    expect(screen).toContain(':aria-label="`Заблокирован: ${account.login}`"')
    expect(screen).toContain(':aria-label="`Сохранить изменения для ${account.login}`"')
    expect(screen).toContain(':aria-label="`Сбросить пароль для ${account.login}`"')
  })

  it('keeps mobile rows compact while exposing the existing save and password reset actions', () => {
    expect(screen).toContain('<details v-for="account in filteredAccounts"')
    expect(screen).toContain('class="admin-mobile-edit"')
    expect(screen).toContain('@click="save(account, $event)"')
    expect(screen).toContain('@click="createReset(account, $event)"')
  })

  it('aligns the mobile member directory with the V2 card grid', () => {
    expect(presentation).toContain('.workspace-main-panel--admin .admin-panel--members .admin-directory { margin-top: 1px; }')
  })

  it('uses the handoff owner login only in visual admin records', () => {
    expect(visualFixture).toContain("login: member.user_id === 'egor-2' ? 'owner' : member.login")
  })
})
