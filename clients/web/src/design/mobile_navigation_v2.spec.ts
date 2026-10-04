import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import workspace from '../workspace/WorkspaceApp.vue?raw'
const mobileNavigation = readFileSync(new URL('./design_v2_mobile_navigation.css', import.meta.url), 'utf8')
const responsiveShell = readFileSync(new URL('./responsive_shell.css', import.meta.url), 'utf8')
const searchLauncher = readFileSync(new URL('../search/SearchLauncher.vue', import.meta.url), 'utf8')
const navigation = readFileSync(new URL('./navigation.css', import.meta.url), 'utf8')
const dock = readFileSync(new URL('../voice/VoiceDock.vue', import.meta.url), 'utf8')

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
    expect(mobileNavigation).toContain('.sidebar.is-open .channel-button.voice-connected:not(.selected) { color: var(--gc-text-secondary); }')
    expect(mobileNavigation).toContain('.sidebar.is-open .channel-button.voice-connected::before { display: none; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .voice-member-list { margin-top: 5px; padding-left: 36px; gap: 0; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .voice-member-row { min-height: 36px; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .voice-member-avatar { width: 22px; height: 22px; flex-basis: 22px; font-size: 9px; }')
  })

  it('shows the connected headset only in the open drawer dock', () => {
    expect(dock).toContain('class="voice-dock-headset"')
    expect(mobileNavigation).toContain('.sidebar.is-open .mobile-voice-dock .voice-dock-headset')
  })

  it('uses the reference search outline and drawer alignment', () => {
    expect(searchLauncher).toContain('<circle cx="10.5" cy="10.5" r="6.5"')
    expect(searchLauncher).toContain('<path d="m16 16 5 5"')
    expect(navigation).toContain('.guild-search-button > svg { width: 16px; height: 16px;')
    expect(mobileNavigation).toContain('.sidebar.is-open > .guild-header { padding-left: 12px; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .guild-search-button { padding: 0 10px;')
    expect(mobileNavigation).toContain('padding: 8px 14px; background: #101218;')
  })
})
