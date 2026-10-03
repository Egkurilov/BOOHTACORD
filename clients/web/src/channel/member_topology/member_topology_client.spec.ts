import { describe, expect, it, vi } from 'vitest'

import { archiveText, createMemberChannel, createMemberCategory, TopologyMutationError } from './member_topology_client'

const id = '11111111-1111-4111-8111-111111111111'
const result = { client_request_id: id, topology_revision: 8, result: { resource_type: 'TEXT_CHANNEL', resource_id: 'channel-1', state: 'ACTIVE' } }

describe('member topology client', () => {
  it('reuses the supplied command id in create requests', async () => {
    const request = vi.fn(async (_input: string, _init: RequestInit) => new Response(JSON.stringify(result), { status: 201 }))
    await createMemberCategory('Игры', id, request)
    expect(JSON.parse(request.mock.calls[0]![1].body as string)).toEqual({ name: 'Игры', client_request_id: id })
    await createMemberChannel('category-1', 'Общий', 'TEXT', id, request)
    expect(request.mock.calls[1]![0]).toContain('/categories/category-1/channels')
  })

  it('sends explicit delete confirmation and exposes authorization failures', async () => {
    const request = vi.fn(async (_input: string, _init: RequestInit) => new Response(JSON.stringify({ error: { code: 'FORBIDDEN', message: 'Нет права' } }), { status: 403 }))
    await expect(archiveText('channel-1', 7, id, request)).rejects.toBeInstanceOf(TopologyMutationError)
    expect(JSON.parse(request.mock.calls[0]![1].body as string)).toEqual({ expected_revision: 7, confirm_archive: true, client_request_id: id })
  })
})
