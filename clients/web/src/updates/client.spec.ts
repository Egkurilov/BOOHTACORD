import { describe, expect, it, vi } from 'vitest'

import { fetchUpdatePolicy } from './client'

describe('client update API', () => {
  it('uses the exact public selector without credentials', async () => {
    const request = vi.fn(async () => new Response(JSON.stringify({
      application_family:'boohtacord', catalog_revision:1, platform:'web', distribution:'browser', channel:'stable', arch:'any', state:'unconfigured', target:null,
    }), { status: 200, headers: { 'content-type':'application/json' } }))
    await fetchUpdatePolicy(request as typeof fetch)
    expect(request).toHaveBeenCalledWith('/api/v1/client-updates?platform=web&distribution=browser&channel=stable&arch=any', expect.objectContaining({ credentials:'omit', cache:'no-store' }))
  })

  it('rejects a policy with another selector', async () => {
    const request = async () => new Response(JSON.stringify({ application_family:'boohtacord', catalog_revision:1, platform:'windows', distribution:'direct', channel:'stable', arch:'x64', state:'unconfigured', target:null }), { headers:{'content-type':'application/json'} })
    await expect(fetchUpdatePolicy(request as typeof fetch)).rejects.toThrow('selector')
  })
})
