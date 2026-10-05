import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { describe, expect, it, vi } from 'vitest'
import OwnSessionsPanel from './OwnSessionsPanel.vue'
const current = { id: 'current', label: 'Вход в приложение', createdAt: '2026-10-05T00:00:00Z', lastActiveAt: '2026-10-05T01:00:00Z', current: true }
const read = vi.fn()
vi.mock('./client', async original => ({ ...(await original<typeof import('./client')>()), loadOwnSessions: (...args: unknown[]) => read(...args) }))
describe('session settings panel', () => {
  it('renders actual rows and protects the current session', async () => {
    read.mockResolvedValue({ accountId: 'A', sessions: [current, { ...current, id: 'other', current: false }], nextCursor: null })
    const html = await renderToString(createSSRApp(OwnSessionsPanel, { accountId: 'A' }))
    expect(html).toContain('Этот сеанс')
    const buttons = html.match(/<button[^>]*data-testid="session-revoke"[^>]*>/g)!
    expect(buttons).toHaveLength(2); expect(buttons[0]).toContain('disabled'); expect(buttons[1]).not.toContain('disabled')
    expect(html).toContain('Завершить все остальные'); expect(html).not.toContain('token_digest')
  })
  it('renders a retryable error without session rows', async () => {
    read.mockRejectedValue(new Error('Нет соединения.'))
    const html = await renderToString(createSSRApp(OwnSessionsPanel, { accountId: 'A' }))
    expect(html).toContain('role="alert"'); expect(html).toContain('Нет соединения.')
    expect(html).not.toContain('data-testid="session-revoke"')
  })
})