import { describe, expect, it } from 'vitest'
import {
  clearWorkspaceChannelLocation,
  findAccessibleWorkspaceChannel,
  isWorkspaceChannelLocationHash,
  parseWorkspaceChannelLocation,
  restoreWorkspaceChannelFromLocation,
  setWorkspaceChannelLocation,
} from './workspace_location'

function historyPort() {
  const calls: Array<{ method: string; state: unknown; url: string | URL | null | undefined }> = []
  return {
    calls,
    history: {
      state: { preserved: 'workspace-state' },
      pushState(state: unknown, _title?: string, url?: string | URL | null) {
        calls.push({ method: 'push', state, url: url == null ? url : String(url) })
      },
      replaceState(state: unknown, _title?: string, url?: string | URL | null) {
        calls.push({ method: 'replace', state, url: url == null ? url : String(url) })
      },
    },
  }
}

describe('workspace channel URL', () => {
  it('parses only the channel fragment and safely decodes its identifier', () => {
    expect(parseWorkspaceChannelLocation('#workspace/channel/channel-42')).toBe('channel-42')
    expect(parseWorkspaceChannelLocation('#workspace/channel/channel%2F42')).toBe('channel/42')
    expect(parseWorkspaceChannelLocation('#workspace/dm/dm-42')).toBeNull()
    expect(parseWorkspaceChannelLocation('#main-region')).toBeNull()
  })

  it('distinguishes malformed workspace channel fragments from unrelated anchors', () => {
    expect(isWorkspaceChannelLocationHash('#workspace/channel/')).toBe(true)
    expect(isWorkspaceChannelLocationHash('#workspace/channel/channel-42')).toBe(true)
    expect(isWorkspaceChannelLocationHash('#main-region')).toBe(false)
  })

  it('resolves a URL channel only when it is present in the current topology', () => {
    const topology = {
      revision: 1,
      categories: [{
        id: 'category-1',
        name: 'Общее',
        position: 0,
        channels: [{ id: 'visible-channel', name: 'видимый', kind: 'TEXT' as const, position: 0, admissionClosed: false }],
      }],
    }

    expect(findAccessibleWorkspaceChannel(topology, 'visible-channel')?.name).toBe('видимый')
    expect(findAccessibleWorkspaceChannel(topology, 'hidden-channel')).toBeNull()
    expect(findAccessibleWorkspaceChannel(null, 'visible-channel')).toBeNull()
  })

  it('waits for topology, selects an accessible direct link, and clears inaccessible ids', () => {
    const { history, calls } = historyPort()
    const selected: string[] = []
    const topology = {
      revision: 1,
      categories: [{
        id: 'category-1',
        name: 'Общее',
        position: 0,
        channels: [{ id: 'visible-channel', name: 'видимый', kind: 'TEXT' as const, position: 0, admissionClosed: false }],
      }],
    }

    expect(restoreWorkspaceChannelFromLocation(
      '#workspace/channel/visible-channel', null, history, 'https://voice.example/',
      (channel) => selected.push(channel.id),
    )).toBe('waiting')
    expect(restoreWorkspaceChannelFromLocation(
      '#workspace/channel/visible-channel', topology, history, 'https://voice.example/',
      (channel) => selected.push(channel.id),
    )).toBe('selected')
    expect(restoreWorkspaceChannelFromLocation(
      '#workspace/channel/hidden-channel', topology, history, 'https://voice.example/#workspace/channel/hidden-channel',
      (channel) => selected.push(channel.id),
    )).toBe('invalid')

    expect(selected).toEqual(['visible-channel'])
    expect(calls).toHaveLength(1)
    expect(calls[0].url).toBe('https://voice.example/')
  })

  it('pushes channel selections while preserving the current state, path, and query', () => {
    const { history, calls } = historyPort()

    setWorkspaceChannelLocation(history, 'https://voice.example/app?mode=compact', 'channel-42')

    expect(calls).toEqual([{
      method: 'push',
      state: history.state,
      url: 'https://voice.example/app?mode=compact#workspace/channel/channel-42',
    }])
  })

  it('replaces transient view entries and skips identical channel locations', () => {
    const { history, calls } = historyPort()

    setWorkspaceChannelLocation(history, 'https://voice.example/app#workspace/channel/channel-1', 'channel-2', true)
    setWorkspaceChannelLocation(history, 'https://voice.example/app#workspace/channel/channel-2', 'channel-2')

    expect(calls).toHaveLength(1)
    expect(calls[0]).toMatchObject({ method: 'replace', state: history.state })
    expect(calls[0].url).toBe('https://voice.example/app#workspace/channel/channel-2')
  })

  it('clears only a workspace channel fragment and preserves other anchors', () => {
    const { history, calls } = historyPort()

    clearWorkspaceChannelLocation(history, 'https://voice.example/app?mode=compact#workspace/channel/channel-42')
    clearWorkspaceChannelLocation(history, 'https://voice.example/app#main-region')

    expect(calls).toEqual([{
      method: 'replace',
      state: history.state,
      url: 'https://voice.example/app?mode=compact',
    }])
  })
})
