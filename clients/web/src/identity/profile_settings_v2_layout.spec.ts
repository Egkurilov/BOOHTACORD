import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const component = readFileSync(new URL('./ProfileSettings.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../design/design_v2_identity.css', import.meta.url), 'utf8')

describe('Design V2 account settings', () => {
  it('keeps profile, security, notifications, and about settings in accessible tabs', () => {
    expect(component).toContain('role="tablist"')
    expect(component.match(/role="tab"/g)).toHaveLength(4)
    expect(component).toContain("activeTab === 'notifications'")
    expect(component).toContain("activeTab === 'about'")
  })

  it('retains avatar, name, password, notification, update, and logout workflows', () => {
    for (const value of ['selectAvatar', 'removeAvatar', 'saveName', 'changePassword', 'NotificationSettings', 'UpdateStatus', "emit('logout')"]) expect(component).toContain(value)
  })

  it('uses the canonical desktop settings card and savebar sizes', () => {
    expect(styles).toContain('min-height: 459px;')
    expect(styles).toContain('height: 57px;')
    expect(styles).toContain('margin: 24px 0 26px;')
  })
})
