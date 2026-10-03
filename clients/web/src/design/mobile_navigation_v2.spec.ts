import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import workspace from '../workspace/WorkspaceApp.vue?raw'
const mobileNavigation = readFileSync(new URL('./design_v2_mobile_navigation.css', import.meta.url), 'utf8')
const responsiveShell = readFileSync(new URL('./responsive_shell.css', import.meta.url), 'utf8')

describe('V2 mobile navigation drawer', () => {
  it('keeps real navigation controls and voice session actions inside the open drawer', () => {
    expect(workspace).toContain('aria-label="Закрыть навигацию"')
    expect(workspace).toContain('@click="toggleNavigation"')
    expect(workspace).toContain('<VoiceDock class="mobile-voice-dock"')
    expect(mobileNavigation).toContain('.sidebar.is-open .mobile-voice-dock.mobile-visible')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer')
  })

  it('uses the handoff background for the connected mobile voice dock', () => {
    expect(responsiveShell).toMatch(/\.sidebar \.mobile-voice-dock\.mobile-visible \{[^}]*background: #10191a;/)
  })

  it('matches the compact voice roster geometry in the open drawer', () => {
    expect(mobileNavigation).toContain('.sidebar.is-open .voice-member-list { margin-top: 5px; padding-left: 36px; gap: 0; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .voice-member-row { min-height: 36px; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .voice-member-avatar { width: 22px; height: 22px; flex-basis: 22px; font-size: 9px; }')
  })
})
