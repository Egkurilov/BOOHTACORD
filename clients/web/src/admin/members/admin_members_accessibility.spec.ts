import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const screen = readFileSync(new URL('./AdminMembersSection.vue', import.meta.url), 'utf8')

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
})
