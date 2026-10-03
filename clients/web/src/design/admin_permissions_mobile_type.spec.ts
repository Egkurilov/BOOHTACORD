import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const css = readFileSync(new URL('./design_v2_admin_permissions.css', import.meta.url), 'utf8')

describe('Design V2 mobile permission table', () => {
  it('uses the handoff label and column header text sizes', () => {
    expect(css).toContain('.workspace-main-panel--admin .role-permission-label { font-size: 13px; }')
    expect(css).toContain('.workspace-main-panel--admin .role-permission-table thead th { font-size: 11px; padding: 0 2px; }')
  })
})
