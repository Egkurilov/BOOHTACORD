import { readFileSync } from 'node:fs'
import { describe, expect, it, vi } from 'vitest'
import { isNewerScreenDescriptor, parseScreenDescriptor } from './descriptor'
import { ScreenProfileMetadataPublisher } from './publisher'

const fixtures = JSON.parse(readFileSync(new URL('../../../../../contracts/screen-share-profile-v1.fixtures.json', import.meta.url), 'utf8'))
const owner = { originId: 'https://app.example.test', accountId: '11111111-1111-4111-8111-111111111111', roomId: 'voice:channel-a' }

function raw(overrides: Record<string, unknown> = {}): string {
  const descriptor = structuredClone(fixtures.validDescriptor)
  descriptor.scope = { origin_id: owner.originId, account_id: owner.accountId, room_id: owner.roomId, media_session_id: 'session-a', publication_generation: 4, operation_revision: 12 }
  return JSON.stringify({ ...descriptor, ...overrides })
}

describe('screen-share descriptor v1', () => {
  it('uses sender descriptor target instead of a stale publication name', () => {
    const descriptor = parseScreenDescriptor(raw(), owner)
    expect(descriptor?.requested_profile_id).toBe('P1080_60')
    expect(descriptor?.scope.publication_generation).toBe(4)
  })

  it('rejects unsupported versions, oversized payloads, extra keys and mismatched owners', () => {
    expect(parseScreenDescriptor(raw({ schema_version: 99 }), owner)).toBeUndefined()
    expect(parseScreenDescriptor(`${raw()}${' '.repeat(4097)}`, owner)).toBeUndefined()
    expect(parseScreenDescriptor(raw({ client_user_id: 'forged' }), owner)).toBeUndefined()
    expect(parseScreenDescriptor(raw(), { ...owner, accountId: '22222222-2222-4222-8222-222222222222' })).toBeUndefined()
    expect(parseScreenDescriptor(raw(), { ...owner, roomId: 'voice:other' })).toBeUndefined()
    expect(parseScreenDescriptor(raw(), { ...owner, originId: 'https://other.example.test' })).toBeUndefined()
  })

  it('keeps late or out-of-order descriptors from replacing the latest confirmed snapshot', () => {
    const previous = parseScreenDescriptor(raw(), owner)!
    const next = JSON.parse(raw())
    next.scope.publication_generation = 5
    next.scope.operation_revision = 13
    expect(isNewerScreenDescriptor(parseScreenDescriptor(JSON.stringify(next), owner)!, previous)).toBe(true)
    expect(isNewerScreenDescriptor(previous, parseScreenDescriptor(JSON.stringify(next), owner)!)).toBe(false)
  })

  it('publishes effective sender settings and increments only confirmed profile revisions', async () => {
    const values: Record<string, string>[] = []
    const publisher = new ScreenProfileMetadataPublisher({ setAttributes: async value => { values.push(value) } }, owner, () => 'session-fixed')
    const capture = { width: 1920, height: 1080 }
    await publisher.publish('P1080_60', 1, capture, [{ maxBitrate: 8_000_000, maxFramerate: 60 }])
    await publisher.publish('P1080_60', 3, capture, [{ maxBitrate: 8_000_000, maxFramerate: 60 }])
    await publisher.publish('P720_60', 5, { width: 1280, height: 720 }, [{ maxBitrate: 4_000_000, maxFramerate: 60 }])
    const first = JSON.parse(values[0]!['boohtacord.screen-share.v1']!)
    const second = JSON.parse(values[1]!['boohtacord.screen-share.v1']!)
    const third = JSON.parse(values[2]!['boohtacord.screen-share.v1']!)
    expect(first.scope).toMatchObject({ media_session_id: 'session-fixed', publication_generation: 1, operation_revision: 1 })
    expect(first.effective_profile.capture).toEqual({ max_width: 1920, max_height: 1080, max_fps: 60 })
    expect(first.capabilities.simulcast).toBe(false)
    expect(second.profile_revision).toBe(first.profile_revision)
    expect(third.profile_revision).toBe(first.profile_revision + 1)
    expect(third.requested_profile_id).toBe('P720_60')
  })

  it('publishes an idle revision when screen capture stops', async () => {
    const values: Record<string, string>[] = []
    const publisher = new ScreenProfileMetadataPublisher({ setAttributes: async value => { values.push(value) } }, owner, () => 'session-stop')
    await publisher.publish('P1080_30', 1, { width: 1920, height: 1080 }, [{ maxBitrate: 5_000_000, maxFramerate: 30 }])
    await publisher.clear()
    const active = JSON.parse(values[0]!['boohtacord.screen-share.v1']!)
    const stopped = JSON.parse(values[1]!['boohtacord.screen-share.v1']!)
    expect(stopped.publisher_state).toBe('idle')
    expect(stopped.scope.operation_revision).toBe(active.scope.operation_revision + 1)
  })

  it('lets a stop revision win when the initial descriptor request is still in flight', async () => {
    let finishFirst!: () => void
    const writes: Record<string, string>[] = []
    const publisher = new ScreenProfileMetadataPublisher({ setAttributes: async value => {
      writes.push(value)
      if (writes.length === 1) await new Promise<void>(resolve => { finishFirst = resolve })
    } }, owner, () => 'session-race')
    const starting = publisher.publish('P1080_30', 1, { width: 1920, height: 1080 }, [{ maxBitrate: 5_000_000, maxFramerate: 30 }])
    await publisher.clear()
    finishFirst(); await starting
    const stopped = JSON.parse(writes[1]!['boohtacord.screen-share.v1']!)
    expect(stopped.publisher_state).toBe('idle')
    expect(stopped.scope.operation_revision).toBe(2)
  })

  it('does not synthesize an effective encoding when sender parameters are unknown', async () => {
    const setAttributes = vi.fn(async () => undefined)
    const publisher = new ScreenProfileMetadataPublisher({ setAttributes }, owner, () => 'session-unknown')
    await expect(publisher.publish('P1080_30', 1, { width: 1920, height: 1080 }, [])).rejects.toThrow('sender encodings')
    expect(setAttributes).not.toHaveBeenCalled()
  })
})
