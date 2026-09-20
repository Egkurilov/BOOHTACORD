import { describe, expect, it, vi } from 'vitest'

import { loadMaintenanceStatus } from './status_client'

describe('maintenance status client', () => {
  it('loads only the public active flag without a session', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ active: true })))

    await expect(loadMaintenanceStatus(request)).resolves.toEqual({ active: true })
    expect(request).toHaveBeenCalledWith('/api/v1/maintenance', expect.objectContaining({ credentials: 'same-origin' }))
  })

  it('rejects a malformed maintenance state', async () => {
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify({ active: 'true' })))

    await expect(loadMaintenanceStatus(request)).rejects.toThrow('некорректный')
  })
})
