import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import workspace from '../workspace/WorkspaceApp.vue?raw'
const mobileNavigation = readFileSync(new URL('./design_v2_mobile_navigation.css', import.meta.url), 'utf8')

describe('V2 mobile navigation drawer', () => {
  it('keeps real navigation controls and voice session actions inside the open drawer', () => {
    expect(workspace).toContain('aria-label="Закрыть навигацию"')
    expect(workspace).toContain('@click="toggleNavigation"')
    expect(workspace).toContain('<VoiceDock class="mobile-voice-dock"')
    expect(mobileNavigation).toContain('.sidebar.is-open .mobile-voice-dock.mobile-visible')
    expect(mobileNavigation).toContain('.sidebar.is-open .user-footer')
  })
})
