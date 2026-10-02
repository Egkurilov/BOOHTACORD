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
})
