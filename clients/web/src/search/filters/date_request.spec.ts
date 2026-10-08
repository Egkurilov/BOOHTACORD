import { describe, expect, it, vi } from 'vitest'
import { searchMessages } from '../search_messages_client'
import { searchDateRange } from './date_range'

describe('date-filtered cursor requests', () => {
  it('retains identical instants and existing filters on every page', async () => {
    const request = vi.fn().mockImplementation(() => Promise.resolve(new Response(JSON.stringify({ messages: [], next_cursor: 'page-two' }))))
    const filters = { ...searchDateRange('2026-10-08', '2026-10-09'), authorId: '11111111-1111-4111-8111-111111111111', hasAttachment: false }
    await searchMessages({ query: 'orbit', ...filters }, request)
    await searchMessages({ query: 'orbit', ...filters, before: 'page-two' }, request)
    const first = new URL(request.mock.calls[0][0], 'http://localhost').searchParams
    const second = new URL(request.mock.calls[1][0], 'http://localhost').searchParams
    expect(first.get('created_from')).toBe(filters.createdFrom)
    expect(first.get('created_before')).toBe(filters.createdBefore)
    expect(second.get('before')).toBe('page-two')
    second.delete('before')
    expect(second.toString()).toBe(first.toString())
  })
})
