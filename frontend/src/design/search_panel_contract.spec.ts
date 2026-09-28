import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'

import searchPanel from '../search/SearchPanel.vue?raw'
import searchLauncher from '../search/SearchLauncher.vue?raw'
import workspaceSearch from '../search/WorkspaceSearchPanel.vue?raw'
import workspace from '../workspace/WorkspaceApp.vue?raw'
import workspaceMain from '../workspace/WorkspaceMain.vue?raw'

function source(path: string): string { return readFileSync(new URL(path, import.meta.url), 'utf8') }

describe('GuildChat unified search design contract', () => {
  it('places SearchPanel in the existing right area or drawer', () => {
    expect(workspace).toContain('data-testid="search-aside-panel"')
    expect(workspace).toContain(":panel=\"activePanel === 'search' ? 'none' : activePanel\"")
    expect(workspace).toContain('activePanel !== \'search\' && (voiceStageWide || selectedDirectMessage || activePanel !== \'none\')')
    expect(workspaceMain).toContain('<ConversationPane')
    expect(workspaceMain).not.toContain('slot name="search"')
    expect(workspace).toContain('<SearchLauncher')
    expect(workspaceSearch).toContain('channelLabels')
    expect(workspaceSearch).toContain('directMessageLabels')
    expect(source('./search.css')).toContain('position: fixed')
  })

  it('matches the desktop search panel width used by Flutter', () => {
    const shell = source('../design/shell.css')
    expect(workspace).toContain("'search-active': activePanel === 'search'")
    expect(workspace).toContain('(activePanel === \'search\' && voiceStageWide)')
    expect(shell).toContain('.gc-shell.search-active:not(.voice-stage-wide) { grid-template-columns: var(--gc-layout-nav-wide) minmax(0, 1fr) 400px; }')
    expect(shell).toContain('.gc-shell.search-active:not(.voice-stage-wide) { grid-template-columns: var(--gc-layout-nav-medium) minmax(0, 1fr) 360px; }')
    expect(source('../design/responsive_shell.css')).toContain('.gc-shell.voice-stage-wide .members { position: absolute;')
  })

  it('keeps search labelled, keyboard reachable, paged, and safe-rendered', () => {
    for (const expected of ['aria-keyshortcuts="Control+K Meta+K"', 'aria-expanded', 'Escape', 'focus()']) expect(searchLauncher).toContain(expected)
    for (const expected of ['role="search"', 'aria-live="polite"', 'aria-busy', 'searchMessages', 'MessageBody', 'Показать ещё']) expect(searchPanel).toContain(expected)
    expect(searchPanel).not.toContain('v-html')
    expect(source('./search.css')).toContain('.search-panel')
  })
})
