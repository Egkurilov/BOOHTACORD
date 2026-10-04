import { describe, expect, it } from 'vitest'
import { updateChannelDescription } from './channel_description_client'

describe('administrator channel description client', () => {
  it('sends an empty description with the expected topology revision', async () => {
    let input = '', init: RequestInit | undefined
    const request = async (url: string, options: RequestInit) => {
      input = url; init = options
      return new Response(JSON.stringify({ id: 'channel-1', description: '', revision: 9 }))
    }
    const result = await updateChannelDescription('channel-1', '', 8, request)
    expect(result).toEqual({ id: 'channel-1', description: '', revision: 9 })
    expect(input).toContain('/admin/channels/channel-1/description')
    expect(init?.credentials).toBe('same-origin')
    expect(JSON.parse(String(init?.body))).toEqual({ description: '', expected_revision: 8 })
  })

  it('rejects overlong input and malformed server replies', async () => {
    const request = async () => new Response(JSON.stringify({ id: 'channel-1', description: 5, revision: 9 }))
    await expect(updateChannelDescription('channel-1', 'a'.repeat(201), 8, request)).rejects.toThrow('200')
    await expect(updateChannelDescription('channel-1', 'OK', 8, request)).rejects.toThrow('некоррект')
  })
})
