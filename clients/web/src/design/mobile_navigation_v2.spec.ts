import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import workspace from '../workspace/WorkspaceApp.vue?raw'
import userFooter from '../workspace/WorkspaceUserFooter.vue?raw'
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
    expect(mobileNavigation).toContain('padding: 12px 14px; background: #0b0d12;')
    expect(mobileNavigation).toContain('background: #0b0d12; font-weight: 400;')
  })

  it('aligns the open drawer account row and keeps settings touchable', () => {
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer {')
    expect(mobileNavigation).toContain('gap: 10px; border-top: 1px solid #292d39; border-right: 0;')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer-profile { gap: 10px; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer .username { gap: 0; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer small { line-height: 16px; }')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer-settings { width: 44px; height: 44px; }')
  })

  it('matches the handoff search and segmented tabs in the open drawer', () => {
    expect(mobileNavigation).toContain('.sidebar.is-open > .nav-drawer { box-sizing: border-box; border-right: 0;')
    expect(mobileNavigation).toContain('.sidebar.is-open .guild-search-button { padding: 0 10px; border: 0; color: #a0a9be;')
    expect(mobileNavigation).toContain('.sidebar.is-open .sidebar-tabs { box-sizing: border-box; width: calc(100% - 24px); height: 40px;')
    expect(mobileNavigation).toContain('.sidebar.is-open .sidebar-tabs button { height: 32px; min-height: 32px;')
    expect(mobileNavigation).toContain('.sidebar.is-open .sidebar-tabs button.is-selected { background: #222631; }')
  })

  it('uses the handoff close and account settings outlines with live handlers', () => {
    expect(workspace).toContain('aria-label="Закрыть навигацию" @click="toggleNavigation"><svg')
    expect(workspace).toContain('d="m6 6 12 12M18 6 6 18"')
    expect(userFooter).toContain('d="m9 3 1-1h4l1 3 3 1 3 1v4l-2 2 1 3-3 3-3-1-2 2H8l-1-3-3-1-2-2 1-4 3-1 1-3Z"')
    expect(userFooter).toContain('@click="emit(\'openSettings\')"')
  })
})
