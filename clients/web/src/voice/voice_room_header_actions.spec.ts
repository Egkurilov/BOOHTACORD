import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

function source(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }

describe('voice room header actions', () => {
  it('opens the existing workspace search without replacing the selected media stream', () => {
    const pane = source('../conversation/ConversationPane.vue')
    const main = source('../workspace/WorkspaceMain.vue')
    const app = source('../workspace/WorkspaceApp.vue')
    expect(pane).toContain("emit('openSearch')")
    expect(pane).toContain('<ConversationOverflowMenu')
    expect(main).toContain('@open-search="emit(\'openSearch\')"')
    expect(app).toContain('@open-search="togglePanel(\'search\')"')
  })

  it('labels the voice menu and uses a participant icon for the member toggle', () => {
    expect(source('../conversation/ConversationPane.vue')).toContain('menu-label="Действия голосового канала"')
    expect(source('../conversation/ConversationOverflowMenu.vue')).toContain(':aria-label="props.menuLabel"')
    expect(source('../shared/workspace_header/WorkspaceHeaderActions.vue')).toContain('M17 20v-2a4 4 0 0 0-4-4')
  })
})
