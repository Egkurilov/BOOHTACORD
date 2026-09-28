import { createSSRApp, h } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it } from 'vitest'

import WorkspaceMain from './WorkspaceMain.vue'

describe('workspace panel navigation', () => {
  it.each(['admin', 'audio', 'profile'] as const)('offers a drawer trigger in the %s panel', async (panel) => {
    const html = await renderToString(createSSRApp({
      render: () => h(WorkspaceMain, {
        accountId: 'account-a', activeVoiceChannel: null, panel, channel: null, directMessage: null, navOpen: false,
        membersOpen: false, showMembers: false, selfDisplayName: null,
        joinVoice: async () => {}, leaveVoice: async () => {}, startScreen: async () => {},
        activationMode: 'VAD' as const, voiceConnection: {} as never,
      }, { [panel]: () => h('h1', panel) }),
    }))

    expect(html).toContain(`data-testid="${panel}-workspace-panel"`)
    expect(html).toContain('aria-label="Открыть навигацию"')
    expect(html).toContain('aria-controls="nav-sidebar"')
    expect(html).toContain('aria-expanded="false"')
  })
})
