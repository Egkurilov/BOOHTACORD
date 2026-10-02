import { describe, expect, it, vi } from 'vitest'

import {
  DirectMessageCandidateRequestError,
  loadDirectMessageCandidates,
  openDirectMessage,
} from './direct_message_candidate_client'

describe('direct-message candidate client', () => {
  it('loads a cursor page and opens the canonical pair', async () => {
    const request = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ candidates: [{ id: 'user-2', display_name: 'Лера' }], next_after: 'user-2' })))
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'dm-1', participant_one_id: 'user-1', participant_two_id: 'user-2', created_at: '2026-09-18T10:00:00Z' })))

    await expect(loadDirectMessageCandidates('user / 1', request)).resolves.toEqual({
      candidates: [{ id: 'user-2', displayName: 'Лера' }], nextAfter: 'user-2',
    })
    await expect(openDirectMessage('user-2', request)).resolves.toMatchObject({
      id: 'dm-1', participantOneId: 'user-1', participantTwoId: 'user-2', createdAt: '2026-09-18T10:00:00Z',
    })
    expect(request).toHaveBeenNthCalledWith(1, '/api/v1/direct-message-candidates?after=user%20%2F%201', expect.objectContaining({ method: 'GET', credentials: 'same-origin' }))
    expect(request).toHaveBeenNthCalledWith(2, '/api/v1/direct-messages', expect.objectContaining({ method: 'POST', credentials: 'same-origin', body: '{"participant_id":"user-2"}' }))
  })

  it('preserves NOT_FOUND when an account became unavailable after listing', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: { code: 'NOT_FOUND' } }), { status: 404 }))

    await expect(openDirectMessage('user-2', request)).rejects.toEqual(expect.objectContaining({
      status: 404, code: 'NOT_FOUND',
    }))
    await expect(openDirectMessage('user-2', request)).rejects.toBeInstanceOf(DirectMessageCandidateRequestError)
  })
})
