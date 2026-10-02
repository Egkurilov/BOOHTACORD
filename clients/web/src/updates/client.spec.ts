import { describe, expect, it, vi } from 'vitest'

import { fetchUpdatePolicy, parsePolicy } from './client'

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

  it('accepts nullable web-only fields and ignores compatible additions', () => {
    const policy = parsePolicy({
      application_family:'boohtacord', catalog_revision:2, platform:'web', distribution:'browser', channel:'stable', arch:'any', state:'published', future_hint:'ignored',
      target:{
        release_id:'web-browser-stable-r40', release_order:40, version:'1.0.26', native_build:null,
        priority:'normal', published_at:'2026-10-03T00:00:00Z', summary:'Обновление', release_notes_url:null,
        requirements:{supported_arches:['any']}, action:{kind:'reload',url:null},
      },
    })
    expect(policy.target?.native_build).toBeNull()
    expect(policy.target?.action?.url).toBeNull()
  })

  it('uses a long retry window for an older backend without the endpoint', async () => {
    const request = async () => new Response('{}', { status:404, headers:{'content-type':'application/json'} })
    await expect(fetchUpdatePolicy(request as typeof fetch)).rejects.toMatchObject({ retryAfterMs:1_800_000 })
  })
})
