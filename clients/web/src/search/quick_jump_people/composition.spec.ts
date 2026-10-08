import { readFileSync } from 'node:fs'
import { expect, it } from 'vitest'

it('search composes navigation without taking ownership of microphone or voice lifecycle', () => {
  const source = readFileSync(new URL('../../workspace/search/WorkspaceSearchPanel.vue', import.meta.url), 'utf8')
  expect(source).not.toContain('useWorkspaceVoiceControls')
  expect(source).toContain('useTopologyStore')
  expect(source).toContain('useVoiceNavigationStore')
})
